import 'package:flutter/material.dart';

Color colorParaParametro(String parametro) {
  final p = parametro.toLowerCase();
  if (p.contains('cloro')) return Colors.amber;
  if (p == 'ph') return Colors.redAccent;
  if (p == 'alcalinidad') return Colors.green;
  if (p == 'cya') return Colors.grey.shade300;
  if (p == 'dureza') return Colors.blueAccent;
  return Colors.transparent; // salinidad o sin color
}
