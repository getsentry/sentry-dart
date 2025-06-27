enum Operation {
  select('select'),
  insert('insert'),
  upsert('upsert'),
  update('update'),
  delete('delete'),
  unknown('unknown');

  final String value;
  const Operation(this.value);
}
