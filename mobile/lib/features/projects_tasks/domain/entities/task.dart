import 'package:freezed_annotation/freezed_annotation.dart';

part 'task.freezed.dart';

/// One Task within a Project — FR-ADM-02, and what C-05 lists and C-06 details
/// (FR-PT-04, FR-PT-05).
///
/// ## The field list is Volume 4 Chapter 4.4 §3's `tasks` table, exactly
///
/// | Column | Here | Null? |
/// |---|---|---|
/// | `id` | [id] | No |
/// | `project_id` | [projectId] | No |
/// | `title` | [title] | No |
/// | `instructions` | [instructions] | No |
/// | `reference_examples` | [referenceExamples] | Yes |
/// | `created_at` | [createdAt] | No |
///
/// ## FR-PT-05's third noun, `requirements`, is deliberately ABSENT
///
/// This is the one place this entity knowingly renders a requirement
/// incompletely, and it is recorded rather than papered over.
///
/// FR-PT-05 asks for *"instructions, reference examples, **and
/// requirements**"*. Volume 2 says the same thing three times — C-06's row,
/// A-05's row, and the Task Detail section list all name **three** things.
/// Volume 4 Chapter 4.4 §3's `tasks` table has **six columns and none of them
/// is `requirements`**.
///
/// There are two readings and this entity picks neither:
///
/// - `requirements` is prose already inside [instructions], and Volume 2 is
///   naming a heading rather than a field; or
/// - `requirements` is a real column Chapter 4.4 omits.
///
/// Folding it into [instructions] would encode the first reading in the type
/// system, and adding a `requirements` field would invent a column the backend
/// does not have and Mission 7 could not populate. **Both are product answers
/// dressed as engineering ones**, so the field is omitted and the drift is
/// logged as an open item for Faisal to settle. When it is settled, one field
/// is added or one doc comment is deleted; neither is a rework.
///
/// ## `referenceExamples` is `List<String>`, defaulting to empty
///
/// Chapter 4.4 §3 types the column `jsonb` and describes it in exactly five
/// words: *"Array of reference media URLs."* That is a list of strings and no
/// chapter gives the elements any further structure, so none is invented.
///
/// The column is nullable and this field is not. A null array and an empty
/// array carry the same fact — this Task has no reference examples — and no
/// chapter distinguishes them, so collapsing them here means C-05 and C-06
/// render one shape rather than branching on a difference that means nothing.
@freezed
class Task with _$Task {
  /// Creates a Task.
  const factory Task({
    required String id,
    required String projectId,
    required String title,
    required String instructions,
    required DateTime createdAt,
    @Default(<String>[]) List<String> referenceExamples,
  }) = _Task;
}
