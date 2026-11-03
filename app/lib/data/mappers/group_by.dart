/// Groups child rows by their parent id in one pass. Shared by every
/// repository that hydrates children so the policy (and its cost) lives in
/// one place.
Map<String, List<C>> groupByParent<C>(
  Iterable<C> children,
  String Function(C child) parentId,
) {
  final out = <String, List<C>>{};
  for (final c in children) {
    out.putIfAbsent(parentId(c), () => []).add(c);
  }
  return out;
}
