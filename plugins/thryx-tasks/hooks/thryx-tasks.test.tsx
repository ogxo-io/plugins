import { expect, mock, test } from 'claude-code/testing'
import type { On } from 'claude-code'

// Fixtures in the shapes the live ThryX MCP server answers (probed 2026-10-31).
const ME = { name: 'Fernando Sobreira', email: 'fbsobreira@devx.cloud' }
const STATUSES = {
  statuses: [
    { category: 'triage', key: 'triage', name: 'Triage' },
    { category: 'unstarted', key: 'backlog', name: 'Backlog' },
    { category: 'unstarted', key: 'ready', name: 'Ready' },
    { category: 'started', key: 'in_progress', name: 'In Progress' },
    { category: 'started', key: 'in_review', name: 'In Review' },
    { category: 'completed', key: 'done', name: 'Done' },
    { category: 'canceled', key: 'canceled', name: 'Canceled' },
  ],
}
const ACTIVE = {
  id: 'c1', name: 'KLC Sprint 109', number: 229, status: 'active',
  completed_issues: 1, total_issues: 4, time_used: { remaining: 3, unit: 'working_days' },
}
const CYCLES = { cycles: [{ id: 'c0', name: 'KLC Sprint 113', number: 1051, status: 'planned', time_used: null }, ACTIVE], truncated: false }
const NO_ACTIVE = { cycles: [CYCLES.cycles[0]], truncated: false }
const CYCLE_ISSUES = {
  issues: [
    { key: 'KLC-1', title: 'Mine in progress', assignee: ME.name, priority: 'medium', status: 'In Progress', status_category: 'started' },
    { key: 'KLC-2', title: 'Theirs in review', assignee: 'Rômulo', priority: 'low', status: 'In Review', status_category: 'started' },
    { key: 'KLC-3', title: 'Mine done', assignee: ME.name, priority: 'high', status: 'Done', status_category: 'completed' },
    { key: 'KLC-4', title: 'Theirs ready', assignee: 'Alex', priority: 'high', status: 'Ready', status_category: 'unstarted' },
    { key: 'KLC-5', title: 'Mine ready', assignee: ME.name, priority: 'urgent', status: 'Ready', status_category: 'unstarted', parent_title: 'Queue' },
  ],
}
const ACTIVITY = {
  activity: [
    { issue_key: 'KLC-2', created_at: '2026-10-31T12:00:00Z' },
    { issue_key: 'KLC-1', created_at: '2026-10-30T12:00:00Z' },
  ],
  window: { oldest_event_at: '2026-10-28T00:00:00Z' },
}
const WORKLOAD = {
  workload: [
    { email: ME.email, name: ME.name, open_issues: 3 },
    { email: 'romulo@klever.io', name: 'Rômulo', open_issues: 2 },
    { email: 'nobody@klever.io', name: 'Idle', open_issues: 0 },
  ],
}
const ISSUES: Record<string, unknown> = {
  [ME.email]: {
    issues: [
      { key: 'KLC-1', title: 'Mine in progress', assignee: ME.name, priority: 'medium', status_name: 'In Progress', status_category: 'started' },
      { key: 'KLC-9', title: 'Mine outside sprint', assignee: ME.name, priority: 'high', status_name: 'In Progress', status_category: 'started' },
      { key: 'KLC-8', title: 'Mine backlog', assignee: ME.name, priority: 'low', status_name: 'Backlog', status_category: 'unstarted' },
    ],
    truncated: false,
  },
  'romulo@klever.io': {
    issues: [{ key: 'KLC-2', title: 'Theirs in review', assignee: 'Rômulo', priority: 'low', status_name: 'In Review', status_category: 'started' }],
    truncated: false,
  },
}
const WORKSPACES = {
  workspaces: [
    { slug: 'klever', name: 'Klever', standing: 'ok', mcp_enabled: true },
    { slug: 'ogxo', name: 'OGXO', standing: 'ok', mcp_enabled: true },
    { slug: 'locked', name: 'Locked', standing: 'sso_required', mcp_enabled: true },
  ],
}
const PROJECTS: Record<string, unknown> = {
  klever: { projects: [{ key: 'KLC', name: 'Klever Blockchain' }, { key: 'WALL', name: 'Wallet' }] },
  ogxo: { projects: [{ key: 'OGX', name: 'OGXO plugins' }] },
}

const ISSUE = {
  key: 'KLC-2', title: 'Theirs in review', issue_type: 'bug', labels: ['sync', 'node'],
  description: '## Context\nThe cost of [verifying](https://x.test) `tx` is high.\n\n- step one\n- step two\n- step three',
  blocked: null,
  pull_requests: [{
    pr_number: 42, repo: 'klever-io/node', state: 'open', draft: false, review_decision: 'changes_requested',
    checks: { ci: { conclusion: 'failure', status: 'completed' }, lint: { conclusion: 'success', status: 'completed' } },
    url: 'https://github.com/klever-io/node/pull/42',
  }],
}
const MANY_NEXT = Array.from({ length: 7 }, (_, i) => ({
  key: `KLC-${100 + i}`, title: `Queued ${i}`, parent_title: 'Queue', assignee: ME.name, priority: i === 6 ? 'urgent' : 'low', status: 'Ready', status_category: 'unstarted',
}))

const READ_ONLY = new Set([
  'execute_read',
  'whoami', 'list_workspaces', 'list_projects', 'list_statuses', 'list_cycles',
  'list_cycle_issues', 'list_issues', 'list_activity', 'get_workload', 'get_issue',
])

type Fake = { flaky?: number; heavy?: boolean; many?: boolean; cycles?: unknown; cycleIssues?: unknown; mine?: unknown; servers?: string[]; core?: string[]; fail?: { tool: string; text?: string; reject?: string } }

const KLC = { workspace: 'klever', project: 'KLC' }
const ROOT = '/repo/a'
const REFUSAL = 'The server-side auto mode classifier gave no verdict for mcp__thryx__list_workspaces: the request that produced this action did not ask for one. Issue the action again once, as-is;'

function engine(on: On, fake: Fake = {}, store: Record<string, unknown> = { boards: { [ROOT]: KLC } }) {
  const calls: { tool: string; args: Record<string, unknown>; server?: string }[] = []
  const fills: string[] = []
  const toasts: string[] = []
  const hints: (string | undefined)[] = []
  const stored: Record<string, unknown> = { ...store }
  const session = { root: ROOT }
  on('session.root', () => ({ value: session.root }))
  on('store.get', (_, e) => ({ value: stored[e.key] }))
  on('store.set', (_, e) => {
    stored[e.key] = e.value
    return { value: undefined }
  })
  const clock = mock.clock(on, { now: Date.parse('2026-10-31T14:00:00Z') })
  on('command.register', () => ({ value: { command: 'thryx-tasks' } }))
  on('ui.open', () => ({ value: { isPlaced: true } }))
  on('ui.toast', (_, e) => {
    toasts.push(e.text)
    return { value: undefined }
  })
  // Stands for the engine's own hint line: records the tail it was handed.
  on('ui.render', { component: 'PromptHint' }, ($, e) => {
    hints.push(e.props.tail)
    const { Text } = $.ui.resolve(e)
    return <Text dimColor>{e.props.hint}{e.props.tail ?? ''}</Text>
  })
  on('ui.copy', () => ({ value: { isCopied: true } }))
  on('prompt.fill', (_, e) => {
    fills.push(e.text)
    return { isFilled: true }
  })
  on('session.start', (_, e) => ({ cwd: e.cwd }))
  on('mcp.call', (_, e) => {
    if (fake.servers && !fake.servers.includes(e.server)) return { deny: `no connected MCP tool "${e.tool}" on a server named "${e.server}"` }
    // The claude.ai connector lists a core set; the rest run through execute_read.
    if (fake.core && e.tool !== 'execute_read' && !fake.core.includes(e.tool)) return { deny: `no connected MCP tool "${e.tool}" on a server named "${e.server}"` }
    calls.push({ tool: e.tool, args: e.args, server: e.server })
    if (e.tool === 'execute_read') {
      const x = e.args as { tool: string; arguments?: Record<string, unknown>; workspace?: string }
      e = { ...e, tool: x.tool, args: { ...(x.arguments ?? {}), ...(x.workspace ? { workspace: x.workspace } : {}) } }
    }
    if (fake.flaky && fake.flaky-- > 0) return { deny: `no connected MCP tool "${e.tool}" on a server named "${e.server}"` }
    if (fake.fail && fake.fail.tool === e.tool) {
      if (fake.fail.reject) return { deny: fake.fail.reject }
      return { value: { content: [{ type: 'text', text: fake.fail.text ?? 'failed' }], isError: true } }
    }
    const a = e.args
    const body =
      e.tool === 'whoami' ? ME
      : e.tool === 'list_workspaces' ? WORKSPACES
      : e.tool === 'list_projects' ? PROJECTS[String(a.workspace)] ?? { projects: [] }
      : e.tool === 'list_statuses' ? STATUSES
      : e.tool === 'list_cycles' ? (fake.cycles ?? CYCLES)
      : e.tool === 'list_cycle_issues' ? fake.cycleIssues ?? (fake.many ? { issues: [...CYCLE_ISSUES.issues, ...MANY_NEXT] } : CYCLE_ISSUES)
      : e.tool === 'get_issue' ? ISSUE
      : e.tool === 'list_activity' && a.issue_key === 'KLC-9' ? { activity: [{ issue_key: 'KLC-9', created_at: '2026-10-21T14:00:00Z' }] }
      : e.tool === 'list_activity' && a.issue_key ? { activity: [] }
      : e.tool === 'list_activity' ? ACTIVITY
      : e.tool === 'get_workload' ? WORKLOAD
      : e.tool === 'list_issues' && fake.heavy && !a.priority ? { issues: [], truncated: true }
      : e.tool === 'list_issues' && fake.heavy ? (a.priority === 'high' ? ISSUES[ME.email] : { issues: [], truncated: false })
      : e.tool === 'list_issues' && fake.mine && a.assignee_email === ME.email ? fake.mine
      : e.tool === 'list_issues' ? ISSUES[String(a.assignee_email)] ?? { issues: [] }
      : null
    if (body === null) throw new Error(`unexpected tool ${e.tool}`)
    return { value: { content: [{ type: 'text', text: JSON.stringify(body) }], isError: false } }
  })
  return { calls, fills, toasts, hints, stored, clock, fake, session }
}

const PANE = {
  plugin: 'thryx-tasks',
  component: 'Pane',
  requestId: 'thryx-tasks',
  props: { title: 'ThryX tasks', isFocused: false, bodyColumns: 90, placement: 'dock', scroll: { offset: 0, bodyRows: 60 }, view: {} },
} as const

async function run($: any, args: string): Promise<{ text?: string }> {
  return $.command.run({ command: 'thryx-tasks', args, origin: { kind: 'person' }, presentation: { isFullscreen: true, columns: 200 } })
}

async function start($: any) {
  await $.session.start({ cwd: '/', surface: 'terminal', isInteractive: true })
}

/** The tail thryx-tasks adds to the hint line under the prompt, as drawn now. */
async function tailOf($: any, hints: (string | undefined)[]): Promise<string | undefined> {
  const ui = await $.ui.mount({
    plugin: 'thryx-tasks',
    surface: 'terminal',
    component: 'PromptHint',
    props: { isDraft: false, isWorking: false, hint: '? for shortcuts' },
  })
  await ui.unmount()
  return hints.at(-1)
}

const W = 'ThryX tasks (klever/KLC)'

test('current sprint + only me: doing, review and up next by default, read-only calls', async ($, on) => {
  const { calls } = engine(on)
  await start($)
  const r = await run($, 'sprint me')
  expect(r.text).toBe(`${W}: KLC Sprint 109 · Only me · Open · 2 tasks: KLC-1, KLC-5`)
  expect(calls.every(c => READ_ONLY.has(c.tool))).toBe(true)
  expect(calls.find(c => c.tool === 'list_cycle_issues')?.args).toEqual({ workspace: 'klever', project_key: 'KLC', cycle: '229' })
})

test('current sprint + all users, active only, lists every started ticket', async ($, on) => {
  engine(on)
  await start($)
  const r = await run($, 'sprint everyone active')
  expect(r.text).toBe(`${W}: KLC Sprint 109 · All users · Active · 2 tasks: KLC-2, KLC-1`)
})

test('the view filter changes what shows without reloading', async ($, on) => {
  const { calls } = engine(on)
  await start($)
  expect((await run($, 'sprint me active')).text).toBe(`${W}: KLC Sprint 109 · Only me · Active · 1 task: KLC-1`)
  const after = calls.length
  expect((await run($, 'done')).text).toBe(`${W}: KLC Sprint 109 · Only me · All statuses · 3 tasks: KLC-1, KLC-3, KLC-5`)
  const ui = await $.ui.mount({ ...PANE, surface: 'terminal' })
  await ui.press({ key: 'show' })
  expect(await ui.find({ type: 'Text', text: /Doing/ })).toBeDefined()
  expect(await ui.find({ type: 'Text', text: /Up next/ })).toBeUndefined()
  expect(calls.length).toBe(after)
  await ui.unmount()
})

test('the me view draws the sprint header, the filter line and Doing / Up next / Done', async ($, on) => {
  engine(on)
  await start($)
  await run($, 'sprint me done')
  for (const surface of ['terminal', 'desktop'] as const) {
    const ui = await $.ui.mount({ ...PANE, surface })
    expect(await ui.find({ type: 'Text', text: '▓▓▓░░░░░░░░░' })).toBeDefined()
    expect(await ui.find({ type: 'Text', text: /1\/4 · 3 work days left · \d\d:\d\d/ })).toBeDefined()
    expect(await ui.find({ type: 'Button', key: 'scope-sprint', text: 'Sprint' })).toBeDefined()
    expect(await ui.find({ type: 'Button', key: 'show', text: '+done' })).toBeDefined()
    expect(await ui.find({ type: 'Button', key: 'board', text: 'KLC·klever ▾' })).toBeDefined()
    expect(await ui.find({ type: 'Text', text: /🚧 Doing 1/ })).toBeDefined()
    expect(await ui.find({ type: 'Text', text: /👀 Review/ })).toBeUndefined()
    expect(await ui.find({ type: 'Text', text: /📋 Up next 1/ })).toBeDefined()
    expect(await ui.find({ type: 'Text', text: /✅ Done 1/ })).toBeDefined()
    expect(await ui.find({ type: 'Button', key: 't:KLC-5', text: /🔴 KLC-5 · Ready/ })).toBeDefined()
    expect(await ui.find({ type: 'Text', text: 'Mine in progress' })).toBeDefined()
    expect(await ui.find({ type: 'Button', key: 't:KLC-3' })).toBeUndefined()
    await ui.press({ key: 'fold:me:done' })
    expect(await ui.find({ type: 'Button', key: 't:KLC-3', text: /^ +KLC-3 · Done/ })).toBeDefined()
    await ui.press({ key: 'fold:me:done' })
    expect(await ui.find({ type: 'Button', key: 'refresh', text: '⟳ refresh' })).toBeDefined()
    expect(await ui.find({ type: 'Text', text: /^Priority 🔴 urgent/ })).toBeDefined()
    await ui.unmount()
  }
})

test('up next is sorted by priority and capped with a count of the rest', async ($, on) => {
  engine(on, { many: true })
  await start($)
  await run($, 'sprint me open')
  const ui = await $.ui.mount({ ...PANE, surface: 'terminal' })
  expect(await ui.find({ type: 'Text', text: /📋 Up next 8 · Queue/ })).toBeDefined()
  expect(await ui.find({ type: 'Button', key: 't:KLC-5', text: /Queue/ })).toBeUndefined()
  const rows = (await ui.findAll({ type: 'Button' })).map(b => b.key).filter(k => k?.startsWith('t:'))
  expect(rows.slice(0, 3)).toEqual(['t:KLC-1', 't:KLC-5', 't:KLC-106'])
  expect(rows.length).toBe(6)
  expect(await ui.find({ type: 'Text', text: /\+3 more/ })).toBeDefined()
  await ui.unmount()
})

test('all tasks + only me reads my open tickets, with cycle, age and stale marks', async ($, on) => {
  const { calls } = engine(on)
  await start($)
  const r = await run($, 'all me')
  expect(r.text).toBe(`${W}: All tasks · Only me · Open · 3 tasks: KLC-1, KLC-9, KLC-8`)
  expect(calls.filter(c => c.tool === 'list_issues').map(c => c.args.assignee_email)).toEqual([ME.email])
  // KLC-9 fell outside the project's activity page: read on its own, KLC-1 not.
  expect(calls.filter(c => c.tool === 'list_activity' && c.args.issue_key).map(c => c.args.issue_key)).toEqual(['KLC-9'])
  const ui = await $.ui.mount({ ...PANE, surface: 'terminal' })
  expect(await ui.find({ type: 'Button', key: 't:KLC-1', text: /KLC-1 · KLC Sprint 109 · 1d$/ })).toBeDefined()
  expect(await ui.find({ type: 'Button', key: 't:KLC-9', text: /KLC-9 · 10d ⏳/ })).toBeDefined()
  expect(await ui.find({ type: 'Text', text: /All open tasks/ })).toBeDefined()
  // KLC-8 is not started and outside the sprint: Backlog, folded, not Up next.
  expect(await ui.find({ type: 'Text', text: /Up next/ })).toBeUndefined()
  expect(await ui.find({ type: 'Text', text: /🗃️ Backlog 1/ })).toBeDefined()
  expect(await ui.find({ type: 'Button', key: 't:KLC-8' })).toBeUndefined()
  await ui.press({ key: 'fold:me:backlog' })
  expect(await ui.find({ type: 'Button', key: 't:KLC-8' })).toBeDefined()
  await ui.unmount()
})

test('all users shows one line per person, me first, and expands', async ($, on) => {
  const { calls } = engine(on)
  await start($)
  const r = await run($, 'all everyone')
  expect(r.text).toBe(`${W}: All tasks · All users · Open · 4 tasks: KLC-2, KLC-1, KLC-9, KLC-8`)
  expect(calls.filter(c => c.tool === 'list_issues').map(c => c.args.assignee_email)).toEqual([ME.email, 'romulo@klever.io'])
  const ui = await $.ui.mount({ ...PANE, surface: 'terminal' })
  const people = (await ui.findAll({ type: 'Button' })).map(b => b.key).filter(k => k?.startsWith('p:'))
  expect(people).toEqual([`p:${ME.name}`, 'p:Rômulo'])
  expect(await ui.find({ type: 'Button', key: `p:${ME.name}`, text: /🚧2 🗃️1/ })).toBeDefined()
  expect(await ui.find({ type: 'Button', key: 't:KLC-2' })).toBeUndefined()
  await ui.press({ key: 'p:Rômulo' })
  expect(await ui.find({ type: 'Text', text: /👀 Review 1/ })).toBeDefined()
  expect(await ui.find({ type: 'Button', key: 't:KLC-2' })).toBeDefined()
  await ui.unmount()
})

test('selecting a task opens its card: PR, checks, excerpt; ask and close', async ($, on) => {
  const { calls, fills } = engine(on)
  await start($)
  await run($, 'sprint everyone')
  const ui = await $.ui.mount({ ...PANE, surface: 'terminal' })
  await ui.press({ key: 'p:Rômulo' })
  await ui.press({ key: 't:KLC-2' })
  expect(calls.find(c => c.tool === 'get_issue')?.args).toEqual({ workspace: 'klever', issue_key: 'KLC-2', include: ['pull_requests'] })
  expect(await ui.find({ type: 'Text', text: /bug · sync, node · Rômulo · KLC Sprint 109/ })).toBeDefined()
  expect(await ui.find({ type: 'Text', text: /PR #42 open · changes requested · 1 check failing/ })).toBeDefined()
  expect(await ui.find({ type: 'Text', text: 'The cost of verifying tx is high.' })).toBeDefined()
  expect(await ui.find({ type: 'Text', text: /step one/ })).toBeUndefined()
  await ui.press({ key: 'ask' })
  expect(fills).toEqual(['About ThryX ticket KLC-2: '])
  await ui.press({ key: 'close' })
  expect(await ui.find({ type: 'Text', text: /PR #42/ })).toBeUndefined()
  await ui.unmount()
})

test('a card that fails to load says why in place', async ($, on) => {
  engine(on, { fail: { tool: 'get_issue', text: 'not found: issue not found' } })
  await start($)
  await run($, 'sprint me')
  const ui = await $.ui.mount({ ...PANE, surface: 'terminal' })
  await ui.press({ key: 't:KLC-1' })
  expect(await ui.find({ type: 'Text', text: /get_issue: not found/ })).toBeDefined()
  expect(await ui.find({ type: 'Button', key: 'ask' })).toBeDefined()
  await ui.unmount()
})

test('a board is set by command, by key or workspace/key, and back to the default', async ($, on) => {
  const { calls } = engine(on)
  await start($)
  expect((await run($, 'board ogxo/ogx')).text).toContain('ThryX tasks (ogxo/OGX)')
  expect(calls.at(-1)?.args.workspace).toBe('ogxo')
  expect(calls.at(-1)?.args.project_key).toBe('OGX')
  expect((await run($, 'board WALL')).text).toContain('ThryX tasks (ogxo/WALL)')
  expect((await run($, 'board default')).text).toContain('no board chosen')
})

test('the board picker lists every reachable workspace\'s projects and switches', async ($, on) => {
  const { calls } = engine(on)
  await start($)
  expect((await run($, 'boards')).text).toBe('Pick a board in the panel (3 boards).')
  expect(calls.filter(c => c.tool === 'list_projects').map(c => c.args.workspace)).toEqual(['klever', 'ogxo'])
  const ui = await $.ui.mount({ ...PANE, surface: 'terminal' })
  expect(await ui.find({ type: 'Text', text: 'Choose a board' })).toBeDefined()
  expect(await ui.find({ type: 'Text', text: '● KLC' })).toBeDefined()
  await ui.press({ key: 'b:ogxo/OGX' })
  expect(calls.at(-1)?.args.workspace).toBe('ogxo')
  expect(await ui.find({ type: 'Button', key: 'board', text: 'OGX·ogxo ▾' })).toBeDefined()
  await ui.unmount()
})

test('no active sprint says so and offers All tasks', async ($, on) => {
  engine(on, { cycles: NO_ACTIVE })
  await start($)
  const r = await run($, 'sprint me')
  expect(r.text).toBe(`${W}: no active sprint · Only me. Run /thryx-tasks all to see all tasks.`)
  const ui = await $.ui.mount({ ...PANE, surface: 'terminal' })
  expect(await ui.find({ type: 'Text', text: 'No active sprint in KLC.' })).toBeDefined()
  await ui.press({ key: 'to-all' })
  expect(await ui.find({ type: 'Button', key: 't:KLC-9' })).toBeDefined()
  await ui.unmount()
})

test('an auth error shows in the panel with a way out, not a crash', async ($, on) => {
  engine(on, { fail: { tool: 'list_cycles', text: '401 Unauthorized: invalid token' } })
  await start($)
  const r = await run($, '')
  expect(r.text).toContain('Reconnect with /thryx:connect')
  const ui = await $.ui.mount({ ...PANE, surface: 'terminal' })
  expect(await ui.find({ type: 'Text', text: /Reconnect with \/thryx:connect/ })).toBeDefined()
  expect(await ui.find({ type: 'Button', key: 'retry' })).toBeDefined()
  expect(await ui.find({ type: 'Button', key: 'err-board' })).toBeDefined()
  await ui.unmount()
})

test('an unreachable server is reported by name', async ($, on) => {
  const { clock } = engine(on, { servers: [] })
  await start($)
  const pending = run($, '')
  await clock.advance(2000)
  expect((await pending).text).toContain('no MCP server named "thryx" or "claude.ai ThryX" is connected')
})

test('with only the claude.ai connector connected, the panel finds and keeps it', async ($, on) => {
  const core = ['whoami', 'list_workspaces', 'list_projects', 'list_statuses', 'list_cycles', 'list_issues', 'get_issue']
  const { calls, clock } = engine(on, { servers: ['claude.ai ThryX'], core })
  await start($)
  const pending = run($, 'sprint me active')
  await clock.advance(2000)
  expect((await pending).text).toBe(`${W}: KLC Sprint 109 · Only me · Active · 1 task: KLC-1`)
  expect(calls.length).toBeGreaterThan(0)
  expect(calls.every(c => c.server === 'claude.ai ThryX')).toBe(true)
  // Tools off the connector's core list go through execute_read, with the workspace beside them.
  const indirect = calls.filter(c => c.tool === 'execute_read')
  expect(indirect.map(c => c.args.tool)).toContain('list_cycle_issues')
  expect(indirect.every(c => c.args.workspace === 'klever' && !('workspace' in (c.args.arguments as object)))).toBe(true)
  expect((await run($, 'permissions')).text).toContain('"mcp__claude_ai_ThryX__whoami"')
})

test('a rate limit waits retry_after before trying again', async ($, on) => {
  engine(on, { fail: { tool: 'list_activity', text: 'rate limited, retry_after: 7' } })
  await start($)
  const r = await run($, '')
  expect(r.text).toContain('retrying in 7s')
})

test('filters and board persist across sessions; an old stored value takes defaults', async ($, on) => {
  const { stored } = engine(on, {}, { filters: { scope: 'all', people: 'everyone', autoOpen: false }, boards: { [ROOT]: KLC } })
  await start($)
  const r = await run($, '')
  expect(r.text).toContain('All tasks · All users · Open')
  const off = await run($, 'auto on sprint me active board WALL')
  expect(off.text).toContain('Auto-open is on.')
  expect(stored.filters).toEqual({ scope: 'sprint', people: 'me', show: 'active', autoOpen: true })
  expect(stored.boards).toEqual({ [ROOT]: { workspace: 'klever', project: 'WALL' } })
})

test('each project root keeps its own board; a board stored before 0.2.0 is dropped', async ($, on) => {
  const { stored, session } = engine(on, {}, { filters: { board: KLC }, boards: { '/repo/b': { workspace: 'klever', project: 'WALL' } } })
  await start($)
  expect((await run($, '')).text).toContain('no board chosen')
  await run($, 'board klever/KLC')
  expect(stored.boards).toEqual({ '/repo/b': { workspace: 'klever', project: 'WALL' }, [ROOT]: KLC })
  expect(stored.filters).not.toHaveProperty('board')
  session.root = '/repo/b'
  await start($)
  expect((await run($, '')).text).toContain('(klever/WALL)')
  await run($, 'board default')
  expect(stored.boards).toEqual({ [ROOT]: KLC })
})

test('an unknown argument is refused with the usage', async ($, on) => {
  engine(on)
  await start($)
  const r = await run($, 'bogus')
  expect(r.text).toContain('Unknown argument: bogus')
  await run($, '')
})

test('a reload reuses statuses and per-ticket reads until a status changes or a refresh is asked for', async ($, on) => {
  const { calls, clock, fake } = engine(on)
  await start($)
  await run($, 'all me')
  const ui = await $.ui.mount({ ...PANE, surface: 'terminal' })
  const reads = () => calls.filter(c => c.tool === 'list_activity' && c.args.issue_key).map(c => c.args.issue_key)
  const statusReads = () => calls.filter(c => c.tool === 'list_statuses').length
  expect(reads()).toEqual(['KLC-9'])
  await clock.advance(5 * 60_000 + 10)
  await clock.settle()
  expect(reads()).toEqual(['KLC-9'])
  expect(statusReads()).toBe(1)
  expect(await ui.find({ type: 'Button', key: 't:KLC-9', text: /KLC-9 · 10d ⏳/ })).toBeDefined()
  const mine = ISSUES[ME.email] as { issues: Record<string, unknown>[] }
  fake.mine = { ...mine, issues: mine.issues.map(t => (t.key === 'KLC-9' ? { ...t, status_name: 'In Review' } : t)) }
  await clock.advance(5 * 60_000 + 10)
  await clock.settle()
  expect(reads()).toEqual(['KLC-9', 'KLC-9'])
  await run($, 'refresh')
  expect(reads()).toEqual(['KLC-9', 'KLC-9', 'KLC-9'])
  expect(statusReads()).toBe(2)
  await ui.unmount()
})

test('the timer refreshes the open panel every refreshMinutes, and not more often', async ($, on) => {
  const { calls, clock, fake } = engine(on)
  await start($)
  await run($, 'sprint everyone')
  const ui = await $.ui.mount({ ...PANE, surface: 'terminal' })
  expect(await ui.find({ type: 'Button', key: 'p:Rômulo' })).toBeDefined()
  const before = calls.length
  await clock.advance(4 * 60_000)
  expect(calls.length).toBe(before)
  fake.cycles = NO_ACTIVE
  await clock.advance(60_000 + 10)
  await clock.settle()
  expect(calls.length).toBeGreaterThan(before)
  expect(await ui.find({ type: 'Text', text: 'No active sprint in KLC.' })).toBeDefined()
  await ui.unmount()
})

test('a manual refresh right after another is ignored', async ($, on) => {
  const { calls } = engine(on)
  await start($)
  await run($, 'refresh')
  const after = calls.length
  const ui = await $.ui.mount({ ...PANE, surface: 'terminal' })
  await ui.press({ key: 'refresh' })
  expect(calls.length).toBe(after)
  await ui.unmount()
})

test('a person with more open tickets than a page is read a priority at a time', async ($, on) => {
  const { calls } = engine(on, { heavy: true })
  await start($)
  const r = await run($, 'all me')
  expect(r.text).toBe(`${W}: All tasks · Only me · Open · 3 tasks: KLC-1, KLC-9, KLC-8`)
  const pages = calls.filter(c => c.tool === 'list_issues')
  expect(pages.map(c => c.args.priority ?? 'any')).toEqual(['any', 'urgent', 'high', 'medium', 'low', 'none'])
  expect(pages.every(c => c.args.limit === 100)).toBe(true)
})

test('plain icons draw ASCII markers', { options: { icons: 'plain' } }, async ($, on) => {
  engine(on)
  await start($)
  await run($, 'sprint me open')
  const ui = await $.ui.mount({ ...PANE, surface: 'terminal' })
  expect(await ui.find({ type: 'Text', text: /\[>\] Doing 1/ })).toBeDefined()
  expect(await ui.find({ type: 'Text', text: /\[ \] Up next 1/ })).toBeDefined()
  expect(await ui.find({ type: 'Text', text: '###---------' })).toBeDefined()
  await ui.unmount()
})

test('a project the workspace lacks says so and points at the picker', async ($, on) => {
  engine(on, { fail: { tool: 'list_statuses', text: 'not found: project not found' } })
  await start($)
  const r = await run($, 'board ogxo/NOPE')
  expect(r.text).toContain('No project NOPE in workspace ogxo. Pick another board')
})

test('a server not yet connected is tried once more', async ($, on) => {
  const { clock } = engine(on, { flaky: 1 })
  await start($)
  const pending = run($, 'sprint me active')
  await clock.advance(2000)
  expect((await pending).text).toBe(`${W}: KLC Sprint 109 · Only me · Active · 1 task: KLC-1`)
})

test('with no board configured the panel asks for one, and the picker sets it', async ($, on) => {
  const { calls } = engine(on, {}, {})
  await start($)
  expect((await run($, '')).text).toContain('no board chosen')
  expect(calls.filter(c => c.tool !== 'list_workspaces' && c.tool !== 'list_projects')).toEqual([])
  const ui = await $.ui.mount({ ...PANE, surface: 'terminal' })
  expect(await ui.find({ type: 'Text', text: 'Pick the ThryX board this panel follows.' })).toBeDefined()
  expect(await ui.find({ type: 'Button', key: 'board', text: 'Board ▾' })).toBeDefined()
  await ui.press({ key: 'choose-board' })
  await ui.press({ key: 'b:klever/KLC' })
  expect(await ui.find({ type: 'Text', text: /KLC Sprint 109/ })).toBeDefined()
  await ui.unmount()
})

test('a reload that finds moved tickets toasts and marks them', async ($, on) => {
  const { toasts, clock, fake } = engine(on)
  await start($)
  await run($, 'sprint everyone')
  const ui = await $.ui.mount({ ...PANE, surface: 'terminal' })
  expect(toasts.filter(t => t.startsWith('ThryX:'))).toEqual([])
  fake.cycleIssues = {
    issues: [
      ...CYCLE_ISSUES.issues.map(i => (i.key === 'KLC-1' ? { ...i, status: 'In Review' } : i)),
      { key: 'KLC-6', title: 'Handed to me', assignee: ME.name, priority: 'high', status: 'Ready', status_category: 'unstarted' },
    ],
  }
  await clock.advance(5 * 60_000 + 10)
  await clock.settle()
  expect(toasts.at(-1)).toBe('ThryX: 2 tickets changed: KLC-1 moved to Review, KLC-6 is now yours')
  await ui.press({ key: `p:${ME.name}` })
  expect(await ui.find({ type: 'Button', key: 't:KLC-1', text: /• moved to Review/ })).toBeDefined()
  expect(await ui.find({ type: 'Button', key: 't:KLC-6', text: /• is now yours/ })).toBeDefined()
  // Marks fade once they are old; a reload with nothing new adds no toast.
  const n = toasts.length
  await clock.advance(15 * 60_000 + 10)
  await clock.settle()
  expect(toasts.length).toBe(n)
  expect(await ui.find({ type: 'Button', key: 't:KLC-1', text: /•/ })).toBeUndefined()
  await ui.unmount()
})

test('a filter change is not reported as moved tickets', async ($, on) => {
  const { toasts } = engine(on)
  await start($)
  await run($, 'sprint me')
  await run($, 'sprint everyone')
  await run($, 'all everyone')
  expect(toasts.filter(t => t.startsWith('ThryX:'))).toEqual([])
})

test('the hint line under the prompt shows my open work and the sprint, even for the everyone view', async ($, on) => {
  const { hints } = engine(on)
  await start($)
  await run($, 'sprint everyone')
  expect(await tailOf($, hints)).toBe(' · KLC 🚧1 👀0 📋1 · S109 3wd')
  await run($, 'board ogxo/OGX')
  expect(await tailOf($, hints)).toBe(' · OGX 🚧1 👀0 📋1 · S109 3wd')
})

test('the hint line summary can be turned off', { options: { statusLine: 'off' } }, async ($, on) => {
  const { hints } = engine(on)
  await start($)
  await run($, 'sprint me')
  expect(await tailOf($, hints)).toBeUndefined()
})

test('the hint line names a missing sprint', async ($, on) => {
  const { hints } = engine(on, { cycles: NO_ACTIVE })
  await start($)
  await run($, 'sprint me')
  expect(await tailOf($, hints)).toBe(' · KLC no active sprint')
})

test('my own card leaves out my name', async ($, on) => {
  engine(on)
  await start($)
  await run($, 'sprint me')
  const ui = await $.ui.mount({ ...PANE, surface: 'terminal' })
  await ui.press({ key: 't:KLC-1' })
  expect(await ui.find({ type: 'Text', text: 'bug · sync, node · KLC Sprint 109' })).toBeDefined()
  await ui.unmount()
})

test('control characters in ThryX text never reach the panel', async ($, on) => {
  const { fake } = engine(on)
  fake.cycleIssues = {
    issues: [{ key: 'KLC-1', title: 'Evil \u001b]0;pwned\u0007title \u001b[31mred\u009b2J', assignee: ME.name, priority: 'medium', status: 'In Progress', status_category: 'started' }],
  }
  await start($)
  const r = await run($, 'sprint me')
  expect(r.text).toContain('KLC-1')
  const ui = await $.ui.mount({ ...PANE, surface: 'terminal' })
  expect(await ui.find({ type: 'Text', text: 'Evil ]0;pwnedtitle [31mred2J' })).toBeDefined()
  expect(await ui.find({ type: 'Text', text: /[\u0000-\u0008\u000b-\u001f\u007f-\u009f]/ })).toBeUndefined()
  await ui.unmount()
})

test('a classifier refusal points at the permission rules, which name only read tools', async ($, on) => {
  engine(on, { fail: { tool: 'list_cycles', text: REFUSAL } })
  await start($)
  const r = await run($, 'sprint me')
  expect(r.text).toContain("auto mode refused the panel's ThryX read")
  expect(r.text).toContain('/thryx-tasks permissions')
  const ui = await $.ui.mount({ ...PANE, surface: 'terminal' })
  expect(await ui.find({ type: 'Text', text: /Run \/thryx-tasks permissions/ })).toBeDefined()
  await ui.unmount()
  const help = (await run($, 'permissions')).text ?? ''
  const rules: string[] = JSON.parse(help.slice(help.indexOf('[')))
  expect(rules).toContain('mcp__thryx__list_workspaces')
  expect(rules).toContain('mcp__thryx__get_issue')
  expect(rules.every(r => READ_ONLY.has(r.replace('mcp__thryx__', '')))).toBe(true)
  expect(rules).toContain('mcp__thryx__execute_read')
  expect(rules.length).toBe(READ_ONLY.size)
})

test('the permission rules follow the server setting', { options: { server: 'claude.ai ThryX' } }, async ($, on) => {
  engine(on)
  await start($)
  await run($, '') // let the session-start load finish before the test ends
  const help = (await run($, 'permissions')).text ?? ''
  expect(help).toContain('"mcp__claude_ai_ThryX__whoami"')
})
