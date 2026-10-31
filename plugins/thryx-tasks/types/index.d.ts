export type ThryxTasksScope = 'sprint' | 'all'
export type ThryxTasksPeople = 'me' | 'everyone'
/** active: doing + review; open: + up next; all: + done (sprint scope only). */
export type ThryxTasksShow = 'active' | 'open' | 'all'
export type ThryxTasksCategory = 'triage' | 'unstarted' | 'started' | 'completed' | 'canceled'
/** next: not started, in the active sprint (or every not-started ticket when there is none); backlog: not started, outside it. */
export type ThryxTasksSection = 'doing' | 'review' | 'next' | 'backlog' | 'done' | 'canceled'

export type ThryxTasksBoard = { workspace: string; project: string }

export type ThryxTasksFilters = {
  scope: ThryxTasksScope
  people: ThryxTasksPeople
  show: ThryxTasksShow
  autoOpen: boolean
  /** null: the workspace and project the mod's settings name. */
  board: ThryxTasksBoard | null
}

export type ThryxTasksTask = {
  key: string
  title: string
  status: string
  category: ThryxTasksCategory
  section: ThryxTasksSection
  assignee: string | null
  priority: string
  estimate: number | null
  epic: string | null
  isBlocked: boolean
  cycle: string | null
  updatedAt: string | null
}

export type ThryxTasksStatus = { key: string; name: string; category: ThryxTasksCategory }

export type ThryxTasksSprint = {
  name: string
  number: number
  remaining: number | null
  unit: string | null
  done: number
  total: number
}

export type ThryxTasksSnapshot = {
  phase: 'empty' | 'ok' | 'no-sprint' | 'no-board' | 'error'
  board: ThryxTasksBoard | null
  /** Every ticket in the scope and people loaded; the view filter applies when drawing. */
  tasks: ThryxTasksTask[]
  sprint: ThryxTasksSprint | null
  statuses: ThryxTasksStatus[]
  meName: string | null
  refreshedAt: number | null
  isRefreshing: boolean
  error: string | null
  notice: string | null
  activitySince: string | null
  /** The board and filters `tasks` was loaded for: a reload for the same one is compared with the last. */
  loadedFor: string | null
  /** Tickets that moved since an earlier load, newest first; each kept a while. */
  changed: ThryxTasksChange[]
}

export type ThryxTasksChange = { key: string; text: string; at: number }

export type ThryxTasksPull = {
  number: number
  repo: string
  state: string
  isDraft: boolean
  review: string | null
  failing: number
  pending: number
  url: string
}

export type ThryxTasksDetail = {
  key: string
  isLoading: boolean
  error: string | null
  type: string | null
  labels: string[]
  excerpt: string[]
  pulls: ThryxTasksPull[]
  blockedReason: string | null
}

export type ThryxTasksView = {
  /** People expanded in the Everyone view, and `done:<owner>` for an opened Done section. */
  expanded: string[]
  detail: ThryxTasksDetail | null
}

export type ThryxTasksBoardOption = ThryxTasksBoard & { workspaceName: string; name: string }

export type ThryxTasksPicker = {
  isOpen: boolean
  isLoading: boolean
  options: ThryxTasksBoardOption[]
  error: string | null
}

declare module 'claude-code' {
  interface PluginState {
    'thryx-tasks': {
      filters: Shaped<ThryxTasksFilters>
      snapshot: Shaped<ThryxTasksSnapshot>
      picker: Shaped<ThryxTasksPicker>
      view: Shaped<ThryxTasksView>
    }
  }
}
