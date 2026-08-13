enum Role {
  collector,
  admin;

  bool get isCollector => this == Role.collector;
  bool get isAdmin => this == Role.admin;
}
