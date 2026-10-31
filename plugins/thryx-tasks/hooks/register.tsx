import { atom, read } from 'claude-code'
import type { EngineInterface, McpToolResult, PluginOptions, Register } from 'claude-code'

import type {
  ThryxTasksBoard as Board,
  ThryxTasksBoardOption as BoardOption,
  ThryxTasksChange as Change,
  ThryxTasksCategory as Category,
  ThryxTasksDetail as Detail,
  ThryxTasksFilters as Filters,
  ThryxTasksPicker as Picker,
  ThryxTasksPull as Pull,
  ThryxTasksSection as Section,
  ThryxTasksShow as Show,
  ThryxTasksSnapshot as Snapshot,
  ThryxTasksStatus as Status,
  ThryxTasksTask as Task,
  ThryxTasksView as View,
} from '../types'

// Read-only by construction: the only ThryX tools this module ever names are
// in READ_TOOLS, and every call goes through thryx(), which refuses any other.
const READ_TOOLS = [
  'whoami',
  'list_workspaces',
  'list_projects',
  'list_statuses',
  'list_cycles',
  'list_cycle_issues',
  'list_issues',
  'list_activity',
  'get_workload',
  'get_issue',
] as const
type ReadTool = (typeof READ_TOOLS)[number]
const NO_WORKSPACE_ARG: readonly ReadTool[] = ['whoami', 'list_workspaces']

const PANE = 'thryx-tasks'
const STORE_FILTERS = 'filters'
// The chosen board, per project root: { [root]: Board }. The other filters are shared.
const STORE_BOARDS = 'boards'
const MANUAL_DEBOUNCE_MS = 10_000
const ACTIVITY_WINDOW = '14d'
// Row sizes against Claude Code's MCP result cap (~80 KB refused): activity
// ~260 characters a row, a ticket ~440, a cycle ~320.
const ACTIVITY_ROWS = 100
const PAGE = 100
const CYCLE_ROWS = 150
const PRIORITIES = ['urgent', 'high', 'medium', 'low', 'none'] as const
// Per-ticket "last updated" reads are for started tickets, at most this many.
const MAX_TICKET_READS = 40
const STALE_DAYS = 3
// Up next, Backlog and Done list this many before "+N more".
const SECTION_CAP = 5
// A moved ticket keeps its mark this long.
const CHANGE_MS = 15 * 60_000

const DEFAULT_FILTERS: Filters = { scope: 'sprint', people: 'me', show: 'open', autoOpen: true, board: null }
const EMPTY: Snapshot = {
  phase: 'empty',
  board: null,
  tasks: [],
  sprint: null,
  statuses: [],
  meName: null,
  refreshedAt: null,
  isRefreshing: false,
  error: null,
  notice: null,
  activitySince: null,
  loadedFor: null,
  changed: [],
}
const CLOSED_PICKER: Picker = { isOpen: false, isLoading: false, options: [], error: null }
const EMPTY_VIEW: View = { expanded: [], detail: null }

const filtersAtom = atom({ plugin: 'thryx-tasks', key: 'filters' } as const, DEFAULT_FILTERS, { shape: 'filters-2' })
const snapAtom = atom({ plugin: 'thryx-tasks', key: 'snapshot' } as const, EMPTY, { shape: 'snapshot-4' })
const pickerAtom = atom({ plugin: 'thryx-tasks', key: 'picker' } as const, CLOSED_PICKER, { shape: 'picker-1' })
const viewAtom = atom({ plugin: 'thryx-tasks', key: 'view' } as const, EMPTY_VIEW, { shape: 'view-1' })
const SNAP_REF = { plugin: 'thryx-tasks', key: 'snapshot' } as const
const FILTERS_REF = { plugin: 'thryx-tasks', key: 'filters' } as const
const PICKER_REF = { plugin: 'thryx-tasks', key: 'picker' } as const
const VIEW_REF = { plugin: 'thryx-tasks', key: 'view' } as const

type Config = {
  server: string
  workspace: string
  project: string
  refreshMinutes: number
  issueUrlTemplate: string
  icons: 'emoji' | 'plain'
  statusLine: boolean
}

function config(options: PluginOptions): Config {
  const str = (k: string, d: string) => {
    const v = options[k]
    return typeof v === 'string' && v.trim() !== '' ? v.trim() : d
  }
  const minutes = Number(options.refreshMinutes ?? 5)
  return {
    server: str('server', 'thryx'),
    workspace: str('workspace', ''),
    project: str('project', ''),
    refreshMinutes: Number.isFinite(minutes) && minutes >= 0 ? minutes : 5,
    issueUrlTemplate: typeof options.issueUrlTemplate === 'string' ? options.issueUrlTemplate.trim() : '',
    icons: options.icons === 'plain' ? 'plain' : 'emoji',
    statusLine: options.statusLine !== 'off',
  }
}

// --- the ThryX connection ----------------------------------------------------

class ThryxError extends Error {
  retryAfter: number | null
  constructor(message: string, retryAfter: number | null = null) {
    super(message)
    this.retryAfter = retryAfter
  }
}

function retryAfterOf(text: string): number | null {
  const m = /retry_after["\s:=]*([0-9]+(?:\.[0-9]+)?)/i.exec(text)
  return m ? Math.ceil(Number(m[1])) : null
}

// Ticket text is written by anyone in the workspace. Control characters
// (escape sequences among them) are dropped before any of it is drawn; line
// breaks and tabs stay. JSON escapes such as \u001b only become characters
// once parsed, so every string of the parsed answer is cleaned too.
const CONTROL = /[\u0000-\u0008\u000b-\u001f\u007f-\u009f]/g

function clean(text: string): string {
  return text.replace(CONTROL, '')
}

function cleanAll(value: unknown): any {
  if (typeof value === 'string') return clean(value)
  if (Array.isArray(value)) return value.map(cleanAll)
  if (value && typeof value === 'object') {
    return Object.fromEntries(Object.entries(value).map(([k, v]) => [clean(k), cleanAll(v)]))
  }
  return value
}

function oneLine(text: string): string {
  const s = text.replace(/\s+/g, ' ').trim()
  return s.length > 240 ? `${s.slice(0, 237)}...` : s
}

// Seen in Claude Desktop's auto mode: the permission classifier gives no
// verdict for a call the panel made on its own, and the call is refused.
const CLASSIFIER = /auto mode classifier|gave no verdict/i

// The names ThryX's server goes by: /thryx:connect adds `thryx`, the claude.ai
// connector is `claude.ai ThryX`. The setting's name is tried first, then these,
// and the first that answers is kept. A mod can't list the session's servers.
const KNOWN_SERVERS = ['thryx', 'claude.ai ThryX']
const NOT_CONNECTED = /no connected mcp tool|is not connected|no such server|unknown server|no mcp server|server .*not connected/i
let server: string | null = null
// The claude.ai connector lists a core set of tools; the rest of its read tools
// run through its `execute_read`. `server|tool` pairs found to need it.
const viaExecute = new Set<string>()

function serversOf(cfg: Config): string[] {
  return server ? [server] : [...new Set([cfg.server, ...KNOWN_SERVERS])]
}

/** The permission rules that allow the panel's read tools, as settings.json spells them. */
function allowRules(cfg: Config): string[] {
  const id = serverOf(cfg).replace(/[^A-Za-z0-9_-]/g, '_')
  return [...READ_TOOLS, 'execute_read'].map(t => `mcp__${id}__${t}`)
}

function serverOf(cfg: Config): string {
  return server ?? cfg.server
}

function permissionsHelp(cfg: Config): string {
  return [
    'Claude\'s auto mode can refuse the panel\'s ThryX calls: its classifier gives no verdict for a call the panel makes on its own.',
    'To allow the panel\'s read tools, and only those, add these to "permissions.allow" in ~/.claude/settings.json, then reopen the panel:',
    JSON.stringify(allowRules(cfg), null, 2),
  ].join('\n')
}

function explain(cfg: Config, text: string): string {
  const t = text.toLowerCase()
  if (CLASSIFIER.test(text)) {
    return 'Claude\'s auto mode refused the panel\'s ThryX read: its classifier gave no verdict for a call the panel made. Run /thryx-tasks permissions for the settings that allow the panel\'s read tools.'
  }
  if (/unauthori[sz]ed|401|403|forbidden|invalid token|authenticat|sso_required|two_step/.test(t)) {
    return `ThryX refused the credential (${oneLine(text)}). Reconnect with /thryx:connect.`
  }
  if (/no connected mcp tool|no such server|unknown server|no mcp server|server .*not connected/.test(t)) {
    return `${oneLine(text)}. Check /mcp or the mod's "server" setting.`
  }
  if (/project not found/.test(t)) {
    return `No project ${cfg.project} in workspace ${cfg.workspace || '(default)'}. Pick another board (b, or /thryx-tasks boards).`
  }
  if (/no workspace/.test(t)) {
    return `${oneLine(text)} Pick another board (b, or /thryx-tasks boards).`
  }
  return oneLine(text)
}

async function thryx(
  $: EngineInterface,
  cfg: Config,
  tool: ReadTool,
  args: Record<string, unknown> = {},
): Promise<any> {
  if (!(READ_TOOLS as readonly string[]).includes(tool)) throw new ThryxError(`refused non-read tool ${tool}`)
  // An empty workspace is left out: ThryX then uses the token's only one.
  const full = NO_WORKSPACE_ARG.includes(tool) || !cfg.workspace ? args : { workspace: cfg.workspace, ...args }
  const names = serversOf(cfg)
  // Each name in turn while none is connected; right after a session starts
  // the server may not be connected yet, so all of them once more after 2s.
  const callOn = async (name: string): Promise<McpToolResult> => {
    const indirect = async () => {
      const { workspace, ...rest } = full as Record<string, unknown>
      const r = await $.mcp.call(name, 'execute_read', { tool, arguments: rest, ...(workspace ? { workspace } : {}) })
      viaExecute.add(`${name}|${tool}`)
      return r
    }
    if (viaExecute.has(`${name}|${tool}`)) return indirect()
    try {
      return await $.mcp.call(name, tool, full)
    } catch (err) {
      if (!NOT_CONNECTED.test(String(err instanceof Error ? err.message : err))) throw err
      // The server may be there without this tool on its list.
      return indirect()
    }
  }
  const attempt = async (): Promise<McpToolResult> => {
    let last: unknown
    for (const name of names) {
      try {
        const r = await callOn(name)
        server = name
        return r
      } catch (err) {
        if (!NOT_CONNECTED.test(String(err instanceof Error ? err.message : err))) {
          // It answered, with a refusal: this is the connected one.
          server = name
          throw err
        }
        last = err
      }
    }
    throw last
  }
  let result
  try {
    try {
      result = await attempt()
    } catch (first) {
      const why = String(first instanceof Error ? first.message : first)
      // An auto-mode classifier that gave no verdict asks for one more try as-is.
      if (NOT_CONNECTED.test(why)) await $.clock.sleep(2000)
      else if (!CLASSIFIER.test(why)) throw first
      result = await attempt()
    }
  } catch (err) {
    const msg = clean(err instanceof Error ? err.message : String(err)).replace(/^thryx-tasks: \$\.mcp\.call: /, '')
    if (CLASSIFIER.test(msg)) throw new ThryxError(explain(cfg, msg))
    if (NOT_CONNECTED.test(msg)) {
      // Probe every name again next time: the connected one may have gone.
      server = null
      viaExecute.clear()
      const tried = names.map(n => `"${n}"`).join(' or ')
      throw new ThryxError(`Can't reach ThryX: no MCP server named ${tried} is connected. Connect one with /thryx:connect, or set the mod's "server" setting to the name /mcp lists.`)
    }
    throw new ThryxError(`Can't reach ThryX via "${serverOf(cfg)}": ${explain(cfg, msg)}`, retryAfterOf(msg))
  }
  const text = clean(result.content.map(b => (typeof b.text === 'string' ? b.text : '')).join('\n'))
  if (result.isError) throw new ThryxError(`${tool}: ${explain(cfg, text || 'failed')}`, retryAfterOf(text))
  if (result.structuredContent !== undefined && result.structuredContent !== null) return cleanAll(result.structuredContent)
  try {
    return cleanAll(JSON.parse(text))
  } catch {
    throw new ThryxError(`${tool}: unreadable answer (${oneLine(text).slice(0, 80)})`)
  }
}

// --- module state ------------------------------------------------------------
// The module keeps the authoritative copies and writes them whole: every
// $.state.get within one dispatch reads one moment, so read-modify-write twice
// in a dispatch would miss. Renders read the state (and subscribe to it).

type Me = { name: string; email: string }
let me: Me | null = null
let inflight: Promise<void> | null = null
let lastManual = 0
let retryTimer: { cancel: () => void } | null = null
let paneOpen = false
let snap: Snapshot = EMPTY
let filters: Filters = DEFAULT_FILTERS
let picker: Picker = CLOSED_PICKER
let view: View = EMPTY_VIEW
let detailSeq = 0
// Per board: its statuses, and each ticket's newest event as last read on its
// own with the status it had then. Both save ThryX calls on every refresh.
const statusCache = new Map<string, Status[]>()
const updatedCache = new Map<string, { status: string; updatedAt: string | null }>()

async function putSnap($: EngineInterface, patch: Partial<Snapshot>): Promise<void> {
  snap = { ...snap, ...patch }
  await $.state.set(SNAP_REF, { shape: 'snapshot-4', value: snap })
}

async function putPicker($: EngineInterface, patch: Partial<Picker>): Promise<void> {
  picker = { ...picker, ...patch }
  await $.state.set(PICKER_REF, { shape: 'picker-1', value: picker })
}

async function putView($: EngineInterface, patch: Partial<View>): Promise<void> {
  view = { ...view, ...patch }
  await $.state.set(VIEW_REF, { shape: 'view-1', value: view })
}

async function setFilters($: EngineInterface, patch: Partial<Filters>): Promise<Filters> {
  const boardChanged = 'board' in patch && JSON.stringify(patch.board) !== JSON.stringify(filters.board)
  filters = { ...filters, ...patch }
  await $.state.set(FILTERS_REF, { shape: 'filters-2', value: filters })
  const { board, ...shared } = filters
  await $.store.set(STORE_FILTERS, shared)
  if (boardChanged) {
    // Read again before writing: another session may have saved its own project's board.
    const boards = asRecord(await $.store.get(STORE_BOARDS))
    const root = await $.session.root()
    if (board) boards[root] = board
    else delete boards[root]
    await $.store.set(STORE_BOARDS, boards)
  }
  return filters
}

function asRecord(v: unknown): Record<string, unknown> {
  return v && typeof v === 'object' && !Array.isArray(v) ? { ...(v as Record<string, unknown>) } : {}
}

function sanitizeBoard(v: unknown): Board | null {
  const b = v as Record<string, unknown> | null | undefined
  return b && typeof b.workspace === 'string' && typeof b.project === 'string'
    ? { workspace: b.workspace, project: b.project }
    : null
}

function sanitize(stored: unknown, board: unknown): Filters {
  const s = asRecord(stored)
  return {
    scope: s.scope === 'all' ? 'all' : 'sprint',
    people: s.people === 'everyone' ? 'everyone' : 'me',
    show: s.show === 'active' || s.show === 'all' ? s.show : 'open',
    autoOpen: s.autoOpen !== false,
    board: sanitizeBoard(board),
  }
}

async function hydrate($: EngineInterface): Promise<void> {
  // After a hot reload the module's variables start over; the state stays.
  snap = await read($, snapAtom)
  picker = await read($, pickerAtom)
  view = await read($, viewAtom)
  // A board saved under `filters` before 0.2.0 was shared by every project; it is dropped.
  const boards = asRecord(await $.store.get(STORE_BOARDS))
  filters = sanitize(await $.store.get(STORE_FILTERS), boards[await $.session.root()])
  await setFilters($, {})
}

function boardOf(cfg: Config): Board {
  return filters.board ?? { workspace: cfg.workspace, project: cfg.project }
}

function withBoard(cfg: Config): Config {
  return { ...cfg, ...boardOf(cfg) }
}

// --- loading -----------------------------------------------------------------

type Raw = {
  key: string
  title: string
  status?: string
  status_name?: string
  status_category?: string | null
  assignee?: string | null
  priority?: string
  estimate?: number | null
  parent_title?: string | null
  blocked?: { by?: { settled?: boolean }[]; reason?: string | null } | null
}

const CATEGORIES: readonly Category[] = ['triage', 'unstarted', 'started', 'completed', 'canceled']
const SHOWN: Record<Show, readonly Section[]> = {
  active: ['doing', 'review'],
  open: ['doing', 'review', 'next', 'backlog'],
  all: ['doing', 'review', 'next', 'backlog', 'done'],
}

function categoryOf(r: Raw, statuses: Status[]): Category {
  const c = r.status_category as Category | null | undefined
  if (c && CATEGORIES.includes(c)) return c
  const name = r.status_name ?? r.status ?? ''
  return statuses.find(s => s.name === name)?.category ?? 'unstarted'
}

function sectionOf(category: Category, status: string, statuses: Status[]): Section {
  if (category === 'started') {
    const key = statuses.find(s => s.name === status)?.key ?? status
    return /review/i.test(key) || /review/i.test(status) ? 'review' : 'doing'
  }
  if (category === 'completed') return 'done'
  if (category === 'canceled') return 'canceled'
  return 'next'
}

function toTask(r: Raw, statuses: Status[], cycle: string | null, updated: Map<string, string>): Task {
  const status = r.status_name ?? r.status ?? '?'
  const category = categoryOf(r, statuses)
  const b = r.blocked
  return {
    key: r.key,
    title: r.title,
    status,
    category,
    section: sectionOf(category, status, statuses),
    assignee: r.assignee ?? null,
    priority: r.priority ?? 'none',
    estimate: typeof r.estimate === 'number' ? r.estimate : null,
    epic: r.parent_title ?? null,
    isBlocked: !!b && (!!b.reason || (b.by ?? []).some(x => x.settled === false)),
    cycle,
    updatedAt: updated.get(r.key) ?? null,
  }
}

function visible(tasks: Task[], f: Filters): Task[] {
  return tasks.filter(t => SHOWN[f.show].includes(t.section))
}

async function openIssuesOf($: EngineInterface, cfg: Config, email: string): Promise<{ rows: Raw[]; isCut: boolean }> {
  const base = { project_key: cfg.project, assignee_email: email, limit: PAGE }
  const one = await thryx($, cfg, 'list_issues', base)
  if (!one.truncated) return { rows: one.issues ?? [], isCut: false }
  // More open tickets than a page: read them a priority at a time.
  const parts = await Promise.all(PRIORITIES.map(priority => thryx($, cfg, 'list_issues', { ...base, priority })))
  return { rows: parts.flatMap(p => p.issues ?? []), isCut: parts.some(p => p.truncated) }
}

// The project's activity page covers only the last day or two of a busy board;
// a started ticket it misses gets its newest event read on its own, once, and
// again only after its status changes.
async function fillUpdated($: EngineInterface, cfg: Config, tasks: Task[]): Promise<Task[]> {
  let budget = MAX_TICKET_READS
  return Promise.all(
    tasks.map(async t => {
      if (t.updatedAt || t.category !== 'started') return t
      const id = `${cfg.workspace}/${cfg.project}|${t.key}`
      const hit = updatedCache.get(id)
      if (hit && hit.status === t.status) return { ...t, updatedAt: hit.updatedAt }
      if (budget-- <= 0) return t
      const a = await thryx($, cfg, 'list_activity', { project_key: cfg.project, issue_key: t.key, limit: 1 })
      const updatedAt: string | null = a.activity?.[0]?.created_at ?? null
      updatedCache.set(id, { status: t.status, updatedAt })
      return { ...t, updatedAt }
    }),
  )
}

async function statusesOf($: EngineInterface, cfg: Config): Promise<Status[]> {
  const id = `${cfg.workspace}/${cfg.project}`
  const hit = statusCache.get(id)
  if (hit) return hit
  const list = await thryx($, cfg, 'list_statuses', { project_key: cfg.project })
  const statuses: Status[] = (list.statuses ?? []).map((s: any) => ({
    key: String(s.key ?? ''),
    name: String(s.name ?? ''),
    category: CATEGORIES.includes(s.category) ? s.category : 'unstarted',
  }))
  statusCache.set(id, statuses)
  return statuses
}

async function load(
  $: EngineInterface,
  cfg: Config,
  f: Filters,
): Promise<Omit<Snapshot, 'isRefreshing' | 'loadedFor' | 'changed'>> {
  if (!me) {
    const who = await thryx($, cfg, 'whoami')
    me = { name: String(who.name ?? ''), email: String(who.email ?? '') }
  }
  const [statuses, cycles, activity] = await Promise.all([
    statusesOf($, cfg),
    thryx($, cfg, 'list_cycles', { project_key: cfg.project, include_descriptions: false, limit: CYCLE_ROWS }),
    thryx($, cfg, 'list_activity', { project_key: cfg.project, since: ACTIVITY_WINDOW, limit: ACTIVITY_ROWS }),
  ])

  // Newest event per ticket: activity comes newest first.
  const updated = new Map<string, string>()
  for (const a of activity.activity ?? []) {
    if (a.issue_key && !updated.has(a.issue_key)) updated.set(a.issue_key, a.created_at)
  }
  const activitySince: string | null = activity.window?.oldest_event_at ?? null

  const active = (cycles.cycles ?? []).find((c: any) => c.status === 'active') ?? null
  const sprint = active
    ? {
        name: String(active.name),
        number: Number(active.number),
        remaining: active.time_used?.remaining ?? null,
        unit: active.time_used?.unit ?? null,
        done: Number(active.completed_issues ?? 0),
        total: Number(active.total_issues ?? 0),
      }
    : null

  let sprintRows: Raw[] = []
  if (active) {
    const ci = await thryx($, cfg, 'list_cycle_issues', { project_key: cfg.project, cycle: String(active.number) })
    sprintRows = ci.issues ?? []
  }
  const sprintKeys = new Set(sprintRows.map(r => r.key))

  const board = { workspace: cfg.workspace, project: cfg.project }
  const base = {
    board,
    statuses,
    meName: me.name,
    refreshedAt: await $.clock.now(),
    error: null,
    activitySince,
    sprint,
  }

  if (f.scope === 'sprint') {
    if (!active) {
      const notice = cycles.truncated ? `Looked at the newest ${CYCLE_ROWS} cycles.` : null
      return { ...base, phase: 'no-sprint', tasks: [], notice }
    }
    const mine = sprintRows.filter(r => f.people === 'everyone' || (r.assignee ?? '') === me!.name)
    const tasks = await fillUpdated($, cfg, mine.map(r => toTask(r, statuses, sprint!.name, updated)))
    return { ...base, phase: 'ok', tasks, notice: null }
  }

  let rows: Raw[] = []
  let isCut = false
  let emails: string[] = [me.email]
  if (f.people === 'everyone') {
    // list_issues has no status filter, so read per person who holds open
    // work in this project.
    const wl = await thryx($, cfg, 'get_workload', { project_key: cfg.project })
    emails = (wl.workload ?? [])
      .filter((p: any) => (p.open_issues ?? 0) > 0 && p.email)
      .map((p: any) => String(p.email))
  }
  for (const list of await Promise.all(emails.map(email => openIssuesOf($, cfg, email)))) {
    rows.push(...list.rows)
    isCut = isCut || list.isCut
  }
  // With a sprint running, Up next is its not-started tickets; the rest is Backlog.
  const all = rows
    .map(r => toTask(r, statuses, sprint && sprintKeys.has(r.key) ? sprint.name : null, updated))
    .map(t => (sprint && t.section === 'next' && !t.cycle ? { ...t, section: 'backlog' as const } : t))
  const tasks = await fillUpdated($, cfg, all)
  const notice = isCut ? `Someone holds over ${PAGE * PRIORITIES.length} open tickets; their list is cut.` : null
  return { ...base, phase: 'ok', tasks, notice }
}

async function refresh($: EngineInterface, cfg: Config, why: 'open' | 'manual' | 'timer' | 'filter'): Promise<void> {
  if (why === 'manual') {
    const now = await $.clock.now()
    if (now - lastManual < MANUAL_DEBOUNCE_MS) return
    lastManual = now
    // A refresh asked for reads everything again.
    statusCache.clear()
    updatedCache.clear()
  }
  if (inflight) {
    // Join the load under way; a filter change needs a load of its own.
    await inflight.catch(() => undefined)
    if (why !== 'filter') return
  }
  retryTimer?.cancel()
  retryTimer = null
  if (!boardOf(cfg).project) {
    await putSnap($, { ...EMPTY, phase: 'no-board', board: boardOf(cfg) })
    return
  }
  const run = (async () => {
    await putSnap($, { isRefreshing: true })
    try {
      const loadedFor = forKey(boardOf(cfg), filters)
      const next = await load($, withBoard(cfg), filters)
      const now = next.refreshedAt ?? (await $.clock.now())
      const isSame = snap.phase === 'ok' && snap.loadedFor === loadedFor
      // Only a reload of what is on screen is compared: the first load and a
      // filter or board change have nothing to compare with.
      const fresh = isSame && (why === 'timer' || why === 'manual') ? diff(snap.tasks, next.tasks, next.meName, now) : []
      const kept = isSame ? snap.changed.filter(c => now - c.at < CHANGE_MS && !fresh.some(x => x.key === c.key)) : []
      await putSnap($, { ...next, isRefreshing: false, loadedFor, changed: [...fresh, ...kept] })
      if (fresh.length) await $.ui.toast(toastOf(fresh))
    } catch (err) {
      const e = err instanceof ThryxError ? err : new ThryxError(err instanceof Error ? err.message : String(err))
      let message = e.message
      if (e.retryAfter !== null) {
        message = `ThryX rate limit: retrying in ${e.retryAfter}s.`
        retryTimer = $.clock.after(e.retryAfter * 1000, () => void refresh($, cfg, 'timer'))
      }
      const board = boardOf(cfg)
      const isSameBoard = snap.board?.workspace === board.workspace && snap.board?.project === board.project
      await putSnap($, {
        phase: 'error',
        isRefreshing: false,
        error: message,
        board,
        ...(isSameBoard ? {} : { sprint: null, tasks: [], statuses: [], changed: [], loadedFor: null }),
      })
    }
  })()
  inflight = run
  try {
    await run
  } finally {
    if (inflight === run) inflight = null
  }
}

function forKey(b: Board, f: Filters): string {
  return `${b.workspace}/${b.project}|${f.scope}|${f.people}`
}

const MOVED_TO: Record<Section, string> = { doing: 'moved to Doing', review: 'moved to Review', next: 'moved to Up next', backlog: 'moved to Backlog', done: 'is done', canceled: 'was canceled' }

function diff(prev: Task[], next: Task[], meName: string | null, now: number): Change[] {
  const before = new Map(prev.map(t => [t.key, t]))
  const out: Change[] = []
  for (const t of next) {
    const p = before.get(t.key)
    const isMine = !!meName && t.assignee === meName
    let text: string | null = null
    if (!p) text = isMine ? 'is now yours' : 'was added'
    else if (p.section !== t.section) text = MOVED_TO[t.section]
    else if (isMine && p.assignee !== t.assignee) text = 'is now yours'
    if (text) out.push({ key: t.key, text, at: now })
  }
  return out
}

function toastOf(changes: Change[]): string {
  const [first] = changes
  if (changes.length === 1 && first) return `ThryX: ${first.key} ${first.text}`
  const list = changes.slice(0, 3).map(c => `${c.key} ${c.text}`).join(', ')
  return `ThryX: ${changes.length} tickets changed: ${list}${changes.length > 3 ? ', …' : ''}`
}

/**
 * The summary added to the hint line under the prompt: your own open work on
 * the board, whatever the panel shows, and the sprint's time left.
 */
function hintOf(cfg: Config, f: Filters, s: Snapshot): string | undefined {
  const b = f.board ?? { workspace: cfg.workspace, project: cfg.project }
  if (!b.project) return undefined
  const emoji = cfg.icons === 'emoji'
  if (s.phase === 'error') return `${b.project} ${emoji ? '⚠️ ' : ''}ThryX error`
  if (s.phase === 'no-sprint' && f.scope === 'sprint') return `${b.project} no active sprint`
  if (s.phase !== 'ok') return undefined
  const mine = s.tasks.filter(t => f.people === 'me' || t.assignee === s.meName)
  const n = (sec: Section) => mine.filter(t => t.section === sec).length
  const counts = emoji
    ? `🚧${n('doing')} 👀${n('review')} 📋${n('next')}`
    : `doing ${n('doing')} review ${n('review')} next ${n('next')}`
  const sp = s.sprint
  if (!sp) return `${b.project} ${counts}`
  // "KLC Sprint 109" → "S109": the project is already named in front.
  const num = /\bsprint\s+(\d+)$/i.exec(sp.name)?.[1]
  const name = num ? `S${num}` : sp.name
  const left = sp.remaining != null ? ` ${sp.remaining}${sp.unit === 'working_days' ? 'wd' : 'd'}` : ''
  return `${b.project} ${counts} · ${name}${left}`
}

// --- the detail card ---------------------------------------------------------

function excerptOf(description: string, maxLines: number): string[] {
  const lines = description
    .split('\n')
    .map(l =>
      l
        .replace(/!?\[([^\]]*)\]\([^)]*\)/g, '$1')
        .replace(/[`*_]/g, '')
        .replace(/^\s*[-+]\s+/, '• ')
        .trim(),
    )
    .map(l => (/^#{1,6}\s/.test(l) || /^(context|today|should|done when|related):?$/i.test(l) ? '' : l))
  // The first paragraph: the lines up to the first blank after some text.
  const start = lines.findIndex(l => l !== '')
  if (start < 0) return []
  const end = lines.indexOf('', start)
  return lines.slice(start, end < 0 ? undefined : end).slice(0, maxLines)
}

function pullOf(p: any): Pull {
  const checks = Object.values((p.checks ?? {}) as Record<string, any>)
  return {
    number: Number(p.pr_number ?? 0),
    repo: String(p.repo ?? ''),
    state: String(p.state ?? 'open'),
    isDraft: p.draft === true,
    review: p.review_decision ?? p.review_state ?? null,
    failing: checks.filter(c => c?.conclusion && !['success', 'neutral', 'skipped'].includes(c.conclusion)).length,
    pending: checks.filter(c => c?.status && c.status !== 'completed').length,
    url: String(p.url ?? ''),
  }
}

async function openDetail($: EngineInterface, cfg: Config, key: string): Promise<void> {
  if (view.detail?.key === key) {
    await putView($, { detail: null })
    return
  }
  const seq = ++detailSeq
  const blank: Detail = { key, isLoading: true, error: null, type: null, labels: [], excerpt: [], pulls: [], blockedReason: null }
  await putView($, { detail: blank })
  try {
    const i = await thryx($, withBoard(cfg), 'get_issue', { issue_key: key, include: ['pull_requests'] })
    if (seq !== detailSeq) return
    await putView($, {
      detail: {
        ...blank,
        isLoading: false,
        type: i.issue_type ? String(i.issue_type).replace(/_/g, ' ') : null,
        labels: Array.isArray(i.labels) ? i.labels.map(String) : [],
        excerpt: excerptOf(String(i.description ?? ''), 3),
        pulls: (i.pull_requests ?? []).map(pullOf),
        blockedReason: i.blocked?.reason ?? null,
      },
    })
  } catch (err) {
    if (seq !== detailSeq) return
    await putView($, { detail: { ...blank, isLoading: false, error: err instanceof Error ? err.message : String(err) } })
  }
}

// Only the key goes into the prompt. A title is written by anyone in the
// workspace, and what the person sends counts as their own words; Claude reads
// the ticket through the ThryX tools, where its text arrives as tool output.
async function askAbout($: EngineInterface, t: Task): Promise<void> {
  await $.prompt.fill({ text: `About ThryX ticket ${t.key}: `, mode: 'append' })
  await $.ui.toast(`${t.key} is in your prompt: type your question`)
}

async function copyKey($: EngineInterface, cfg: Config, key: string, surface: string): Promise<void> {
  const text = linkFor(cfg, key) ?? key
  const c = await $.ui.copy({ text, surface: surface as any })
  await $.ui.toast(c.isCopied ? `Copied ${text}` : `Could not copy: ${(c as any).reason ?? 'no clipboard'}`)
}

async function toggleOpen($: EngineInterface, name: string): Promise<void> {
  const has = view.expanded.includes(name)
  await putView($, { expanded: has ? view.expanded.filter(n => n !== name) : [...view.expanded, name] })
}

// --- the board picker --------------------------------------------------------

async function loadBoards($: EngineInterface, cfg: Config): Promise<BoardOption[]> {
  const ws = await thryx($, cfg, 'list_workspaces')
  const usable = (ws.workspaces ?? []).filter((w: any) => w.slug && (w.standing ?? 'ok') === 'ok' && w.mcp_enabled !== false)
  const lists = await Promise.all(
    usable.map(async (w: any) => {
      const p = await thryx($, { ...cfg, workspace: String(w.slug) }, 'list_projects')
      return (p.projects ?? []).map((x: any) => ({
        workspace: String(w.slug),
        workspaceName: String(w.name ?? w.slug),
        project: String(x.key),
        name: String(x.name ?? x.key),
      }))
    }),
  )
  return lists.flat()
}

async function showPicker($: EngineInterface, cfg: Config): Promise<void> {
  await putPicker($, { ...CLOSED_PICKER, isOpen: true, isLoading: true })
  try {
    await putPicker($, { isLoading: false, options: await loadBoards($, cfg), error: null })
  } catch (err) {
    await putPicker($, { isLoading: false, error: err instanceof Error ? err.message : String(err) })
  }
}

async function chooseBoard($: EngineInterface, cfg: Config, board: Board | null): Promise<void> {
  await putPicker($, CLOSED_PICKER)
  await setFilters($, { board })
  await putView($, EMPTY_VIEW)
  await refresh($, cfg, 'filter')
}

// --- arguments ---------------------------------------------------------------

type Parsed = { patch: Partial<Filters>; force: boolean; pick: boolean; help: boolean; bad: string[] }

function parseArgs(args: string, current: Board): Parsed {
  const patch: Partial<Filters> = {}
  const bad: string[] = []
  let force = false
  let pick = false
  let help = false
  const words = args.split(/\s+/).filter(Boolean)
  for (let i = 0; i < words.length; i++) {
    const raw = words[i] ?? ''
    const w = raw.toLowerCase()
    if (w === 'sprint' || w === 'current') patch.scope = 'sprint'
    else if (w === 'all') patch.scope = 'all'
    else if (w === 'me' || w === 'mine') patch.people = 'me'
    else if (w === 'everyone' || w === 'team' || w === 'users') patch.people = 'everyone'
    else if (w === 'active' || w === 'open') patch.show = w
    else if (w === 'done' || w === 'statuses') patch.show = 'all'
    else if (w === 'refresh') force = true
    else if (w === 'permissions') help = true
    else if (w === 'boards' || (w === 'board' && !words[i + 1])) pick = true
    else if (w === 'board') {
      const target = words[++i] ?? ''
      if (target.toLowerCase() === 'default') patch.board = null
      else if (target.includes('/')) {
        const [workspace, project] = target.split('/')
        if (workspace && project) patch.board = { workspace, project: project.toUpperCase() }
        else bad.push(`board ${target}`)
      } else patch.board = { workspace: current.workspace, project: target.toUpperCase() }
    } else if (w === 'auto' && (words[i + 1] === 'on' || words[i + 1] === 'off')) {
      patch.autoOpen = words[++i] === 'on'
    } else bad.push(raw)
  }
  return { patch, force, pick, help, bad }
}

const USAGE =
  'Use: /thryx-tasks [sprint|all] [me|everyone] [active|open|done] [board <workspace>/<KEY> | board <KEY> | boards | board default] [refresh] [auto on|off] [permissions]'

// --- drawing helpers ---------------------------------------------------------

const SECTION_EMOJI: Record<Section, string> = { doing: '🚧', review: '👀', next: '📋', backlog: '🗃️', done: '✅', canceled: '❌' }
const SECTION_PLAIN: Record<Section, string> = { doing: '[>]', review: '[?]', next: '[ ]', backlog: '[.]', done: '[x]', canceled: '[-]' }
const SECTION_TITLE: Record<Section, string> = { doing: 'Doing', review: 'Review', next: 'Up next', backlog: 'Backlog', done: 'Done', canceled: 'Canceled' }
const SECTION_ORDER: readonly Section[] = ['doing', 'review', 'next', 'backlog', 'done']
const PRIORITY_EMOJI: Record<string, string> = { urgent: '🔴', high: '🟠', medium: '🟡', low: '🔵', none: '⚪' }
const PRIORITY_PLAIN: Record<string, string> = { urgent: '!!!', high: '!! ', medium: '!  ', low: '.  ', none: '   ' }
const LEGEND_EMOJI = 'Priority 🔴 urgent 🟠 high 🟡 medium 🔵 low ⚪ none · ⛔ blocked · ⏳ idle 3d+'
const LEGEND_PLAIN = 'Priority !!! urgent  !! high  ! medium  . low · [!] blocked · stale: idle 3d+'
const PRIORITY_RANK: Record<string, number> = { urgent: 0, high: 1, medium: 2, low: 3, none: 4 }
const VIEW_LABEL: Record<Show, string> = { active: 'doing+review', open: '+up next', all: '+done' }
const NEXT_SHOW: Record<Show, Show> = { active: 'open', open: 'all', all: 'active' }

function sectionIcon(cfg: Config, s: Section): string {
  return (cfg.icons === 'plain' ? SECTION_PLAIN : SECTION_EMOJI)[s]
}

function priorityIcon(cfg: Config, priority: string): string {
  return (cfg.icons === 'plain' ? PRIORITY_PLAIN : PRIORITY_EMOJI)[priority] ?? (cfg.icons === 'plain' ? '   ' : '⚪')
}

function ageMs(iso: string | null, now: number): number | null {
  return iso ? Math.max(0, now - Date.parse(iso)) : null
}

function ago(iso: string | null, now: number, since: string | null): string {
  const ms = ageMs(iso, now)
  if (ms === null) {
    if (!since) return ''
    return `>${Math.max(1, Math.floor((now - Date.parse(since)) / 86_400_000))}d`
  }
  const s = Math.round(ms / 1000)
  if (s < 60) return 'now'
  if (s < 3600) return `${Math.floor(s / 60)}m`
  if (s < 86_400) return `${Math.floor(s / 3600)}h`
  return `${Math.floor(s / 86_400)}d`
}

function hhmm(ms: number): string {
  const d = new Date(ms)
  const p = (n: number) => String(n).padStart(2, '0')
  return `${p(d.getHours())}:${p(d.getMinutes())}`
}

function cut(text: string, width: number): string {
  return text.length > width ? `${text.slice(0, Math.max(1, width - 1))}…` : text
}

/** Up to `max` lines of `width`, broken at spaces, the last cut with an ellipsis. */
function wrapLines(text: string, width: number, max: number): string[] {
  const out: string[] = []
  let rest = text.trim()
  while (rest && out.length < max - 1 && rest.length > width) {
    const at = rest.lastIndexOf(' ', width)
    const split = at > width * 0.5 ? at : width
    out.push(rest.slice(0, split).trimEnd())
    rest = rest.slice(split).trimStart()
  }
  if (rest) out.push(cut(rest, width))
  return out
}

function twoLines(text: string, width: number): string[] {
  return wrapLines(text, width, 2)
}

function bar(cfg: Config, done: number, total: number, width = 12): string {
  const filled = total > 0 ? Math.round((done / total) * width) : 0
  const [on, off] = cfg.icons === 'plain' ? ['#', '-'] : ['▓', '░']
  return on.repeat(filled) + off.repeat(width - filled)
}

function byUpdated(a: Task, b: Task): number {
  if (a.updatedAt && b.updatedAt) return b.updatedAt.localeCompare(a.updatedAt)
  if (a.updatedAt) return -1
  if (b.updatedAt) return 1
  return a.key.localeCompare(b.key)
}

function keyNumber(key: string): number {
  return Number(/(\d+)$/.exec(key)?.[1] ?? 0)
}

function bySection(section: Section) {
  // What to pick up next goes by priority; what is moving, by its last change.
  return section === 'next' || section === 'backlog'
    ? (a: Task, b: Task) => (PRIORITY_RANK[a.priority] ?? 9) - (PRIORITY_RANK[b.priority] ?? 9) || keyNumber(a.key) - keyNumber(b.key)
    : byUpdated
}

function linkFor(cfg: Config, key: string): string | null {
  if (!cfg.issueUrlTemplate) return null
  const b = boardOf(cfg)
  return cfg.issueUrlTemplate
    .replaceAll('{key}', key)
    .replaceAll('{workspace}', b.workspace)
    .replaceAll('{project}', b.project)
}

const SHOW_LABEL: Record<Show, string> = { active: 'Active', open: 'Open', all: 'All statuses' }

function summary(cfg: Config, f: Filters, s: Snapshot): string {
  const b = boardOf(cfg)
  if (!b.project) return 'ThryX tasks: no board chosen. Pick one with /thryx-tasks boards, or /thryx-tasks board <workspace>/<KEY>.'
  const where = `ThryX tasks (${b.workspace ? `${b.workspace}/` : ''}${b.project})`
  const scope = f.scope === 'sprint' ? (s.sprint?.name ?? 'Current sprint') : 'All tasks'
  const people = f.people === 'me' ? 'Only me' : 'All users'
  if (s.phase === 'error') return `${where}: ${scope} · ${people} · error: ${s.error}`
  if (s.phase === 'no-sprint') return `${where}: no active sprint · ${people}. Run /thryx-tasks all to see all tasks.`
  const shown = visible(s.tasks, f)
  const keys = [...shown].sort(byUpdated).map(t => t.key)
  const n = shown.length
  return `${where}: ${scope} · ${people} · ${SHOW_LABEL[f.show]} · ${n} task${n === 1 ? '' : 's'}${keys.length ? `: ${keys.join(', ')}` : ''}${s.notice ? ` (${s.notice})` : ''}`
}

async function openPane($: EngineInterface, focus: boolean): Promise<void> {
  paneOpen = true
  await $.ui.open({ id: PANE, title: 'ThryX tasks', ...(focus ? { focus: true as const } : {}) })
}

async function changeFilters($: EngineInterface, cfg: Config, patch: Partial<Filters>): Promise<void> {
  const prev = filters
  const nf = await setFilters($, patch)
  // The view filter is applied when drawing: only scope and people reload.
  if (nf.scope !== prev.scope || nf.people !== prev.people) await refresh($, cfg, 'filter')
}

// --- register ----------------------------------------------------------------

export const register: Register = (on, options) => {
  const cfg = config(options)
  // New settings may name another server or token: read everything again.
  server = null
  viaExecute.clear()
  statusCache.clear()
  updatedCache.clear()

  on('session.start', async ($, e, next) => {
    await $.command.register({
      name: 'thryx-tasks',
      description: 'Open the ThryX tasks panel (sprint board, filters, board picker)',
      argumentHint: '[sprint|all] [me|everyone] [active|open|done] [board <ws>/<KEY>|boards] [refresh] [auto on|off] [permissions]',
    })
    await hydrate($)
    if (filters.autoOpen) void openPane($, false)
    // The prompt's hint line shows the board with the panel closed, so it loads too.
    if (filters.autoOpen || cfg.statusLine) void refresh($, cfg, 'open')
    if (cfg.refreshMinutes > 0) {
      $.clock.every(cfg.refreshMinutes * 60_000, () => {
        if (paneOpen || cfg.statusLine) void refresh($, cfg, 'timer')
      })
    }
    return next(e)
  })

  on('ui.close', async ($, e, next) => {
    const r = await next(e)
    if (e.id === PANE) paneOpen = false
    return r
  }).catch(($, e, next) => next(e))

  on('command.run', { command: 'thryx-tasks' }, async ($, e) => {
    const { patch, force, pick, help, bad } = parseArgs(e.args ?? '', boardOf(cfg))
    if (bad.length) return { text: `Unknown argument: ${bad.join(' ')}. ${USAGE}` }
    if (help) return { text: permissionsHelp(cfg) }
    const before = filters
    const f = await setFilters($, patch)
    const boardChanged = JSON.stringify(f.board) !== JSON.stringify(before.board)
    const changed = boardChanged || f.scope !== before.scope || f.people !== before.people
    await openPane($, true)
    if (pick) {
      await showPicker($, cfg)
      const n = picker.options.length
      return { text: picker.error ? `ThryX boards: ${picker.error}` : `Pick a board in the panel (${n} board${n === 1 ? '' : 's'}).` }
    }
    if (boardChanged) await putView($, EMPTY_VIEW)
    if (changed || force || snap.phase === 'empty' || snap.phase === 'error' || snap.phase === 'no-board') {
      if (force) lastManual = 0
      await refresh($, cfg, changed ? 'filter' : 'manual')
    } else if (inflight) {
      await inflight.catch(() => undefined)
    }
    const auto = patch.autoOpen === undefined ? '' : ` Auto-open is ${f.autoOpen ? 'on' : 'off'}.`
    return { text: summary(cfg, f, snap) + auto }
  })

  // The board summary rides at the end of the hint line under the prompt.
  on('ui.render', { component: 'PromptHint' }, async ($, e, next) => {
    if (!cfg.statusLine) return next(e)
    const text = hintOf(cfg, await read($, filtersAtom), await read($, snapAtom))
    if (!text) return next(e)
    const tail = e.props.tail ? `${e.props.tail} · ${text}` : ` · ${text}`
    return next({ ...e, props: { ...e.props, tail } })
  })

  on('ui.render', { component: 'Pane', requestId: PANE }, async ($, e) => {
    const { Box, Text, Button } = $.ui.resolve(e)
    const f = await read($, filtersAtom)
    const s = await read($, snapAtom)
    const p = await read($, pickerAtom)
    const v = await read($, viewAtom)
    const now = await $.clock.now()
    const width = Math.max(30, e.props.bodyColumns ?? e.viewport?.columns ?? 60)
    const board = f.board ?? { workspace: cfg.workspace, project: cfg.project }
    const emoji = cfg.icons === 'emoji'

    // One line of toggles: the hotkey, then the label, the chosen one bold.
    const tab = (key: string, hotkey: string, label: string, isOn: boolean, onPress: () => unknown) => (
      <Button key={key} plain hotkey={hotkey} onPress={onPress}>
        <Text bold={isOn} color={isOn ? 'suggestion' : undefined} dimColor={!isOn}>{label}</Text>
      </Button>
    )
    const sep = <Text dimColor>│</Text>
    const boardLabel = board.project ? `${board.project}${board.workspace ? `·${board.workspace}` : ''} ▾` : 'Board ▾'
    const filterLine = (
      <Box flexDirection="row" flexWrap="wrap" columnGap={1}>
        {tab('scope-sprint', 's', 'Sprint', f.scope === 'sprint', () => changeFilters($, cfg, { scope: 'sprint' }))}
        {tab('scope-all', 'a', 'All', f.scope === 'all', () => changeFilters($, cfg, { scope: 'all' }))}
        {sep}
        {tab('people-me', 'm', 'Me', f.people === 'me', () => changeFilters($, cfg, { people: 'me' }))}
        {tab('people-all', 'e', 'Everyone', f.people === 'everyone', () => changeFilters($, cfg, { people: 'everyone' }))}
        {sep}
        {tab('show', 'v', VIEW_LABEL[f.show], true, () => changeFilters($, cfg, { show: NEXT_SHOW[f.show] }))}
        {sep}
        {tab('board', 'b', boardLabel, false, () => showPicker($, cfg))}
        {tab('refresh', 'r', s.isRefreshing ? '⟳ refreshing…' : '⟳ refresh', false, () => refresh($, cfg, 'manual'))}
        {tab('auto', 'o', f.autoOpen ? 'auto ✓' : 'auto ✗', false, () => changeFilters($, cfg, { autoOpen: !f.autoOpen }))}
      </Box>
    )

    if (p.isOpen) {
      const current = (o: Board) => o.workspace === board.workspace && o.project === board.project
      return (
        <Box flexDirection="column">
          <Text bold>Choose a board</Text>
          {p.isLoading && <Text dimColor>Loading workspaces and projects…</Text>}
          {p.error && <Text color="error">{p.error}</Text>}
          {p.options.map(o => (
            <Button key={`b:${o.workspace}/${o.project}`} plain onPress={() => chooseBoard($, cfg, { workspace: o.workspace, project: o.project })}>
              <Text bold={current(o)}>{current(o) ? '● ' : '  '}{o.project}</Text>
              <Text dimColor> {cut(`${o.name} · ${o.workspaceName}`, width - o.project.length - 4)}</Text>
            </Button>
          ))}
          <Box flexDirection="row" columnGap={1} marginTop={1}>
            {f.board && cfg.project && <Button key="board-default" onPress={() => chooseBoard($, cfg, null)}>{`Default (${cfg.workspace ? `${cfg.workspace}/` : ''}${cfg.project})`}</Button>}
            <Button key="board-cancel" role="dismiss" onPress={() => putPicker($, CLOSED_PICKER)}>Cancel</Button>
          </Box>
        </Box>
      )
    }

    // Header: the sprint and its progress, or the scope, and when it loaded.
    const when = s.refreshedAt ? hhmm(s.refreshedAt) : ''
    const header =
      f.scope === 'sprint' && s.sprint ? (
        <Text>
          <Text bold>{s.sprint.name}</Text>{' '}
          <Text color="success">{bar(cfg, s.sprint.done, s.sprint.total)}</Text>
          <Text dimColor>
            {' '}{s.sprint.done}/{s.sprint.total}
            {s.sprint.remaining != null ? ` · ${s.sprint.remaining} ${s.sprint.unit === 'working_days' ? 'work days' : 'days'} left` : ''}
            {when ? ` · ${when}` : ''}
          </Text>
        </Text>
      ) : (
        <Text>
          <Text bold>{board.project ? `${board.project} · ${f.scope === 'sprint' ? 'Current sprint' : 'All open tasks'}` : 'ThryX tasks'}</Text>
          <Text dimColor>{when ? ` · ${when}` : ''}</Text>
        </Text>
      )

    const indent = (n: number) => ' '.repeat(n)

    const row = (t: Task, pad: number, hideEpic: boolean) => {
      const ms = ageMs(t.updatedAt, now)
      const isStale = t.category === 'started' && (ms === null ? !!s.activitySince : ms > STALE_DAYS * 86_400_000)
      const meta: string[] = []
      if (t.section === 'next' || t.section === 'backlog' || t.section === 'done') meta.push(t.status)
      if (t.estimate != null) meta.push(`${t.estimate}pt`)
      if (t.epic && !hideEpic) meta.push(t.epic)
      if (f.scope === 'all' && t.cycle) meta.push(t.cycle)
      const age = ago(t.updatedAt, now, s.activitySince)
      if (age && t.section !== 'next' && t.section !== 'backlog') meta.push(age + (isStale ? (emoji ? ' ⏳' : ' stale') : ''))
      // Finished work needs no priority: a blank keeps the column, and the row is dimmed.
      const isDone = t.section === 'done'
      const lead = isDone ? (emoji ? '  ' : '   ') : t.isBlocked ? (emoji ? '⛔' : '[!]') : priorityIcon(cfg, t.priority)
      const isOpen = v.detail?.key === t.key
      const change = s.changed.find(c => c.key === t.key)
      const titleWidth = width - pad - 3
      return (
        <Box key={`r:${t.key}`} flexDirection="column">
          <Button key={`t:${t.key}`} plain onPress={() => openDetail($, cfg, t.key)}>
            {indent(pad)}{lead}{' '}
            <Text bold={!isDone} dimColor={isDone && !isOpen} color={isOpen ? 'suggestion' : undefined}>{t.key}</Text>
            {change && <Text color="suggestion">{` • ${change.text}`}</Text>}
            <Text dimColor>{meta.length ? ` · ${cut(meta.join(' · '), Math.max(8, width - pad - t.key.length - 6 - (change ? change.text.length + 3 : 0)))}` : ''}</Text>
          </Button>
          {twoLines(t.title, titleWidth).map((line, i) => (
            <Text key={`l:${t.key}:${i}`} dimColor={t.section === 'done'}>{indent(pad + 3)}{line}</Text>
          ))}
          {isOpen && card(t, pad + 3)}
        </Box>
      )
    }

    const card = (t: Task, pad: number) => {
      const d = v.detail!
      const inner = width - pad - 4
      const facts = [d.type, d.labels.length ? d.labels.join(', ') : null, t.assignee === s.meName ? null : (t.assignee ?? 'Unassigned'), t.cycle].filter(Boolean) as string[]
      return (
        <Box flexDirection="column" marginLeft={pad} borderStyle="round" borderDimColor paddingX={1}>
          {d.isLoading && <Text dimColor>Loading {t.key}…</Text>}
          {d.error && <Text color="error">{cut(d.error, inner * 2)}</Text>}
          {!d.isLoading && !d.error && (
            <Box flexDirection="column">
              {facts.length > 0 && <Text dimColor>{cut(facts.join(' · '), inner)}</Text>}
              {(d.blockedReason || t.isBlocked) && <Text color="error">{emoji ? '⛔ ' : ''}Blocked{d.blockedReason ? `: ${cut(d.blockedReason, inner - 10)}` : ''}</Text>}
              {d.pulls.length === 0 && <Text dimColor>No pull request linked</Text>}
              {d.pulls.map(pr => (
                <Text key={`pr:${pr.repo}#${pr.number}`}>
                  {pr.state === 'merged' ? (emoji ? '🟣' : '[m]') : pr.state === 'closed' ? (emoji ? '⚫' : '[c]') : pr.isDraft ? (emoji ? '📝' : '[d]') : emoji ? '🟢' : '[o]'}{' '}
                  PR #{pr.number} {pr.isDraft ? 'draft' : pr.state}
                  <Text dimColor>
                    {pr.review ? ` · ${pr.review.replace(/_/g, ' ')}` : ''}
                    {pr.failing ? ` · ${pr.failing} check${pr.failing === 1 ? '' : 's'} failing` : pr.pending ? ` · ${pr.pending} running` : pr.state === 'open' ? ' · checks pass' : ''}
                  </Text>
                </Text>
              ))}
              {d.excerpt.length > 0 && (
                <Box flexDirection="column" marginTop={1}>
                  {(d.excerpt[0]?.startsWith('• ') ? d.excerpt.map(l => cut(l, inner)) : wrapLines(d.excerpt.join(' '), inner, 3)).map((l, i) => (
                    <Text key={`x:${i}`} dimColor>{l}</Text>
                  ))}
                </Box>
              )}
            </Box>
          )}
          <Box flexDirection="row" columnGap={3} marginTop={1}>
            <Button key="ask" plain hotkey="c" onPress={() => askAbout($, t)}><Text color="suggestion">Ask Claude</Text></Button>
            <Button key="copy" plain hotkey="k" onPress={press => copyKey($, cfg, t.key, press.surface)}>{linkFor(cfg, t.key) ? 'Copy link' : 'Copy key'}</Button>
            <Button key="close" plain hotkey="x" onPress={() => putView($, { detail: null })}>Close</Button>
          </Box>
        </Box>
      )
    }

    const sections = (tasks: Task[], pad: number, owner: string) =>
      SECTION_ORDER.filter(sec => SHOWN[f.show].includes(sec)).map(sec => {
        const list = tasks.filter(t => t.section === sec).sort(bySection(sec))
        if (list.length === 0) return null
        // Done and Backlog fold to one line until opened.
        const isFoldable = sec === 'done' || sec === 'backlog'
        const foldKey = `${sec}:${owner}`
        const isFolded = isFoldable && !v.expanded.includes(foldKey) && !list.some(t => t.key === v.detail?.key)
        // One epic for the whole section is named once, in its title.
        const epics = new Set(list.map(t => t.epic))
        const [only] = epics
        const shared = list.length > 1 && epics.size === 1 && only ? only : null
        const capped = sec === 'next' || isFoldable ? list.slice(0, SECTION_CAP) : list
        const keepOpen = v.detail && list.some(t => t.key === v.detail!.key) && !capped.some(t => t.key === v.detail!.key)
        const shown = keepOpen ? [...capped, list.find(t => t.key === v.detail!.key)!] : capped
        const title = (
          <Text bold>
            {indent(pad)}{sectionIcon(cfg, sec)} {SECTION_TITLE[sec]} <Text dimColor>{list.length}</Text>
            {shared && <Text dimColor>{` · ${cut(shared, Math.max(8, width - pad - 16))}`}</Text>}
          </Text>
        )
        return (
          <Box key={`sec:${owner}:${sec}`} flexDirection="column" marginTop={1}>
            {isFoldable ? (
              <Button key={`fold:${owner}:${sec}`} plain onPress={() => toggleOpen($, foldKey)}>
                {title}
                <Text dimColor>{isFolded ? ' ▸' : ' ▾'}</Text>
              </Button>
            ) : (
              title
            )}
            {!isFolded && shown.map(t => row(t, pad, !!shared))}
            {!isFolded && list.length > shown.length && <Text dimColor>{indent(pad + 3)}+{list.length - shown.length} more</Text>}
          </Box>
        )
      })

    let body
    if (s.phase === 'error') {
      body = (
        <Box flexDirection="column" marginTop={1}>
          <Text color="error">{emoji ? '⚠️ ' : ''}{s.error}</Text>
          <Box flexDirection="row" columnGap={1}>
            <Button key="retry" onPress={async () => { lastManual = 0; await refresh($, cfg, 'manual') }}>Retry</Button>
            <Button key="err-board" onPress={() => showPicker($, cfg)}>Pick another board</Button>
          </Box>
        </Box>
      )
    } else if (s.phase === 'no-board') {
      body = (
        <Box flexDirection="column" marginTop={1}>
          <Text>Pick the ThryX board this panel follows.</Text>
          <Button key="choose-board" variant="primary" onPress={() => showPicker($, cfg)}>Choose a board</Button>
        </Box>
      )
    } else if (s.phase === 'no-sprint') {
      body = (
        <Box flexDirection="column" marginTop={1}>
          <Text>No active sprint in {board.project}.</Text>
          <Button key="to-all" variant="primary" onPress={() => changeFilters($, cfg, { scope: 'all' })}>Show all tasks</Button>
        </Box>
      )
    } else if (s.phase === 'empty') {
      body = <Text dimColor>Loading ThryX tasks…</Text>
    } else if (visible(s.tasks, f).length === 0) {
      body = (
        <Box marginTop={1}>
          <Text dimColor>Nothing {f.show === 'active' ? 'in progress or review' : 'here'} right now.{f.show === 'active' ? ' Press v to see what is up next.' : ''}</Text>
        </Box>
      )
    } else if (f.people === 'me') {
      body = <Box flexDirection="column">{sections(s.tasks, 0, 'me')}</Box>
    } else {
      // Everyone: one line per person with their counts, expandable.
      const groups = new Map<string, Task[]>()
      for (const t of visible(s.tasks, f)) {
        const k = t.assignee ?? 'Unassigned'
        groups.set(k, [...(groups.get(k) ?? []), t])
      }
      const names = [...groups.keys()].sort((a, b) =>
        a === s.meName ? -1 : b === s.meName ? 1 : a === 'Unassigned' ? 1 : b === 'Unassigned' ? -1 : a.localeCompare(b),
      )
      const nameWidth = Math.min(24, Math.max(...names.map(n => n.length)))
      body = (
        <Box flexDirection="column" marginTop={1}>
          {names.map(n => {
            const list = groups.get(n)!
            const isOpen = v.expanded.includes(n)
            const counts = SECTION_ORDER.filter(sec => SHOWN[f.show].includes(sec))
              .map(sec => [sec, list.filter(t => t.section === sec).length] as const)
              .filter(([, c]) => c > 0)
              .map(([sec, c]) => `${sectionIcon(cfg, sec)}${c}`)
              .join(' ')
            return (
              <Box key={`pg:${n}`} flexDirection="column">
                <Button key={`p:${n}`} plain onPress={() => toggleOpen($, n)}>
                  <Text dimColor>{isOpen ? '▾' : '▸'} </Text>
                  <Text bold={n === s.meName}>{cut(n, nameWidth).padEnd(nameWidth)}</Text>
                  {'  '}{counts}
                </Button>
                {isOpen && <Box flexDirection="column">{sections(list, 2, n)}</Box>}
              </Box>
            )
          })}
        </Box>
      )
    }

    return (
      <Box flexDirection="column">
        {header}
        {filterLine}
        {s.notice && <Text color="warning">{s.notice}</Text>}
        <Box flexDirection="column">{body}</Box>
        {s.phase === 'ok' && visible(s.tasks, f).length > 0 && (
          <Box marginTop={1}>
            <Text dimColor>{emoji ? LEGEND_EMOJI : LEGEND_PLAIN}</Text>
          </Box>
        )}
      </Box>
    )
  })
}
