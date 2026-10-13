import 'package:flutter/material.dart';

class MusicFilter {
  final String id;
  final String label;
  final IconData? icon;

  const MusicFilter({
    required this.id,
    required this.label,
    this.icon,
  });

  static const List<MusicFilter> defaults = [
    MusicFilter(
      id: 'all',
      label: 'Semua',
      icon: Icons.graphic_eq,
    ),
    MusicFilter(
      id: 'recent',
      label: 'Baru Ditambahkan',
    ),
    MusicFilter(
      id: 'frequent',
      label: 'Sering Diputar',
    ),
    MusicFilter(
      id: 'lofi',
      label: 'Instrumen • Lofi',
      icon: Icons.nightlight_round,
    ),
    MusicFilter(
      id: 'flac',
      label: 'FLAC Lossless',
      icon: Icons.high_quality,
    ),
  ];
}
