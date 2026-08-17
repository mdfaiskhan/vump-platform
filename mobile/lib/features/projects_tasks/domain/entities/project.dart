import 'package:freezed_annotation/freezed_annotation.dart';

part 'project.freezed.dart';

/// One Admin-created Project — FR-ADM-01, and the unit a Collector browses in
/// C-04 (FR-PT-03).
///
/// ## The field list is Volume 4 Chapter 4.4 §2's `projects` table, exactly
///
/// Chapter 4.6 §6 **defers** full field types to a generated OpenAPI schema
/// that does not exist, so Chapter 4.6's endpoint catalog is not the authority
/// on shape — Chapter 4.4's Data Dictionary is, and every field below is one
/// of its seven columns with its nullability preserved:
///
/// | Column | Here | Null? |
/// |---|---|---|
/// | `id` | [id] | No |
/// | `org_id` | [orgId] | No |
/// | `name` | [name] | No |
/// | `description` | [description] | Yes |
/// | `created_by` | [createdBy] | No |
/// | `created_at` | [createdAt] | No |
/// | `archived_at` | [archivedAt] | Yes |
///
/// **Nothing was added and nothing was dropped.** Mission 7 replaces the fake
/// repository with one that calls `GET /v1/projects`; a domain entity carrying
/// fields the table does not have would make that a rewrite rather than a
/// substitution, which is the whole reason the shape was traced before it was
/// typed.
///
/// ## `orgId` and `createdBy` are carried even though C-04 does not render
/// them
///
/// They are non-null columns. Dropping a non-null column from the entity means
/// the real repository has to discard data the backend sent, and the first
/// surface that needs it — Admin's A-02, or any BR-20 org assertion — would
/// have to widen the entity and every mapper with it. Carrying them costs two
/// fields; omitting them costs a migration.
///
/// ## `archivedAt` is a timestamp, not a boolean
///
/// Chapter 4.2 §1 makes soft-delete a `deleted_at` timestamp deliberately, so
/// that archived data stays queryable. Narrowing it to `isArchived` here would
/// discard *when*, and no chapter says the Collector's list filters archived
/// Projects — so this entity records the fact and decides nothing about it.
@freezed
class Project with _$Project {
  /// Creates a Project.
  const factory Project({
    required String id,
    required String orgId,
    required String name,
    required String createdBy,
    required DateTime createdAt,
    String? description,
    DateTime? archivedAt,
  }) = _Project;
}
