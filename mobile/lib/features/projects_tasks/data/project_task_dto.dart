/// The wire shape of Volume 4 Chapter 4.4's `projects` and `tasks` rows.
///
/// ## The mapping is a transcription, not a translation
///
/// `ProjectDto` in `functions/projects/src/index.ts` is Chapter 4.4 §2's seven
/// columns in `snake_case`; `Project` is the same seven in `camelCase`. A-097
/// traced the entity from the same table the backend selects from, so the two
/// halves agree by construction — *"nothing was added and nothing was
/// dropped"*. Everything below is that agreement made executable.
///
/// Every name is the column's, lower-snake on the wire and lower-camel in the
/// entity: `org_id` / `orgId`, `created_by` / `createdBy`, `created_at` /
/// `createdAt`, `archived_at` / `archivedAt`, `project_id` / `projectId`,
/// `reference_examples` / `referenceExamples`. No field is renamed, merged or
/// derived.
///
/// ## Timestamps arrive in the Data API's format, not ISO-8601
///
/// Aurora's Data API renders `timestamptz` as `2026-08-19 10:00:00+00` — a
/// **space** separator and a two-digit offset. Dart's `DateTime.parse` accepts
/// that grammar and returns a UTC instant, which was verified against the exact
/// strings the backend's tests assert on rather than assumed from the shape.
/// [_dateTime] therefore does no reformatting; what it adds is the refusal.
///
/// ## A missing required field is raised, not defaulted
///
/// Chapter 4.4 makes `id`, `name`, `created_by` and `created_at` `NOT NULL`. A
/// response without one is not a Project with a blank name — it is a response
/// this client cannot read, and `NETWORK_SERIALIZATION` is what says so. The
/// alternative is a Project titled `''` rendering in C-04 as though it were
/// real, which is the same class of substitution A-068's Guard 1 refuses on the
/// recording side.
///
/// The **nullable** columns are the exception and are read as such:
/// `description` and `archived_at` are nullable in the table, and
/// `reference_examples` is nullable there and collapsed to empty here — A-097's
/// reading, because *"a null array and an empty array carry the same fact"*.
library;

import 'package:mobile/core/errors/error_codes.dart';
import 'package:mobile/core/errors/exceptions/network_exception.dart';
import 'package:mobile/features/projects_tasks/domain/entities/project.dart';
import 'package:mobile/features/projects_tasks/domain/entities/task.dart';

/// Decodes one `projects` row.
Project projectFromJson(Map<String, Object?> row) {
  return Project(
    id: _string(row, 'id'),
    orgId: _string(row, 'org_id'),
    name: _string(row, 'name'),
    createdBy: _string(row, 'created_by'),
    createdAt: _dateTime(row, 'created_at'),
    description: _optionalString(row, 'description'),
    archivedAt: _optionalDateTime(row, 'archived_at'),
  );
}

/// Decodes one `tasks` row.
Task taskFromJson(Map<String, Object?> row) {
  return Task(
    id: _string(row, 'id'),
    projectId: _string(row, 'project_id'),
    title: _string(row, 'title'),
    instructions: _string(row, 'instructions'),
    createdAt: _dateTime(row, 'created_at'),
    referenceExamples: _stringList(row, 'reference_examples'),
  );
}

String _string(Map<String, Object?> row, String field) {
  final Object? value = row[field];
  if (value is! String || value.isEmpty) {
    throw _malformed('a $field that is not a non-empty string');
  }
  return value;
}

String? _optionalString(Map<String, Object?> row, String field) {
  final Object? value = row[field];
  return value is String && value.isNotEmpty ? value : null;
}

DateTime _dateTime(Map<String, Object?> row, String field) {
  final DateTime? parsed = DateTime.tryParse(_string(row, field));
  if (parsed == null) {
    throw _malformed('a $field that is not a timestamp');
  }
  return parsed;
}

DateTime? _optionalDateTime(Map<String, Object?> row, String field) {
  final String? raw = _optionalString(row, field);
  return raw == null ? null : DateTime.tryParse(raw);
}

/// Reads `jsonb` array of strings, collapsing null and absent to empty.
///
/// A non-string element is dropped rather than raised. Chapter 4.4 §3 describes
/// the column in five words — *"Array of reference media URLs"* — and gives the
/// elements no further structure, so one unreadable entry is not grounds to
/// refuse the whole Task.
List<String> _stringList(Map<String, Object?> row, String field) {
  final Object? value = row[field];
  if (value is! List) {
    return const <String>[];
  }
  return <String>[
    for (final Object? item in value)
      if (item is String) item,
  ];
}

NetworkException _malformed(String what) => NetworkException(
  errorCode: ErrorCode.networkSerialization,
  message: 'The backend returned $what.',
);
