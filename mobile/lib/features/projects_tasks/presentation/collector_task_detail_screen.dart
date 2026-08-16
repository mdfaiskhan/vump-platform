import 'package:flutter/material.dart';

/// One Task, and the only route to the Pre-Recording Checklist (C-06).
///
/// Still the placeholder Mission 1.3's navigation skeleton registered — it
/// renders nothing but its own name. Volume 2 Chapter 2.3 §2 gives it
/// Instructions, Examples and Requirements, and §5 makes it the sole path
/// toward capture; building that is Mission 5.1.3's.
///
/// ## It now reads the `projectId` its route always carried
///
/// **This is the narrow half of open item 70, and it closes here.**
///
/// Volume 4 Chapter 4.6 §3 has no `GET /v1/tasks/{id}` — the three Task
/// routes are `GET /v1/projects/{id}/tasks`, `POST /v1/projects/{id}/tasks`
/// and `PATCH /v1/tasks/{id}` — so a single Task is reachable only through
/// its Project's list, and `ProjectTaskRepository` declares no by-id fetch
/// for that reason.
///
/// That looked like it left this screen unable to resolve anything. It does
/// not: the route is `/collector/projects/:projectId/tasks/:taskId`, so the
/// owning Project has been in the path since Mission 1.3 and was simply never
/// read. Taking it here means 5.1.3 can select this Task out of
/// `tasksProvider(projectId)` with no new endpoint, no client-side scan across
/// every Project, and no local cache.
///
/// **What does NOT close is `/checklist/:taskId`**, a top-level modal route
/// carrying no Project at all, and Chapter 2.4 §2's Record tab, which is
/// specified to jump into *"the most relevant in-progress Task's checklist"*
/// from a session. Both still need a `taskId → projectId` resolution that no
/// endpoint and no cache provides. Open item 70 stays open for them.
class CollectorTaskDetailScreen extends StatelessWidget {
  /// Creates the screen for [taskId] inside [projectId].
  const CollectorTaskDetailScreen({
    required this.projectId,
    required this.taskId,
    super.key,
  });

  /// The owning Project, from the route path.
  ///
  /// Required rather than nullable: every route that reaches this screen
  /// nests it under `:projectId`, and accepting null would invite a second
  /// route that does not — which is the shape that made open item 70 a
  /// problem in the first place.
  final String projectId;

  /// Identifier supplied by the route path.
  final String taskId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Task')),
      body: Center(child: Text('Collector Task $taskId in $projectId')),
    );
  }
}
