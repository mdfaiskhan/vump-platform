/**
 * `tasks` — Tasks and their assignments. ADR-015 domain: tasks.
 *
 * Routes served, from Volume 4 Chapter 4.6's catalogue:
 *
 *   GET /v1/projects/{projectId}/tasks
 *   POST /v1/projects/{projectId}/tasks
 *   PATCH /v1/tasks/{taskId}
 *   POST /v1/tasks/{taskId}/assignments
 *   DELETE /v1/tasks/{taskId}/assignments/{userId}
 *
 * ## Every route here is provisioned and unimplemented, deliberately
 *
 * Each answers with a named `NOT_IMPLEMENTED` refusal in a real Chapter 4.6 §1
 * envelope. **Token verification runs first and is real** — an invalid or
 * expired bearer token gets `AUTH_TOKEN_INVALID` and never reaches the stub, so
 * the authentication path is demonstrable today while the queries behind it are
 * not. Mission 6.3 replaces the stubs; Mission 6.2 does not invent their data.
 */
import { createRouter, notImplementedRoute, routeKey, type RouteTable } from '@vump/shared';

const routes: RouteTable = {
  [routeKey('GET', '/v1/projects/{projectId}/tasks')]: notImplementedRoute(
    'GET /v1/projects/{projectId}/tasks',
    "Listing a project's tasks",
  ),
  [routeKey('POST', '/v1/projects/{projectId}/tasks')]: notImplementedRoute(
    'POST /v1/projects/{projectId}/tasks',
    'Creating a task',
  ),
  [routeKey('PATCH', '/v1/tasks/{taskId}')]: notImplementedRoute(
    'PATCH /v1/tasks/{taskId}',
    'Editing a task',
  ),
  [routeKey('POST', '/v1/tasks/{taskId}/assignments')]: notImplementedRoute(
    'POST /v1/tasks/{taskId}/assignments',
    'Assigning a Collector to a task',
  ),
  [routeKey('DELETE', '/v1/tasks/{taskId}/assignments/{userId}')]: notImplementedRoute(
    'DELETE /v1/tasks/{taskId}/assignments/{userId}',
    'Removing a Collector from a task',
  ),
};

export const handler = createRouter('tasks', routes);
