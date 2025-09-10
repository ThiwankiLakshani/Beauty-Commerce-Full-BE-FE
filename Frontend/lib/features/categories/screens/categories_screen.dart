// lib/features/categories/screens/categories_screen.dart
//


import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_constants.dart';
import '../../../common/widgets/app_bar_primary.dart';
import '../../../common/widgets/empty_state.dart';
import '../../../common/widgets/text_field.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  final _searchCtrl = TextEditingController();

  bool _loading = true;
  String? _error;

  List<CategoryItem> _all = [];
  List<CategoryItem> _filtered = [];

  @override
  void initState() {
    super.initState();
    _fetchCategories();
    _searchCtrl.addListener(_applyFilter);
  }

  @override
  void dispose() {
    _searchCtrl.removeListener(_applyFilter);
    _searchCtrl.dispose();
    super.dispose();
  }

  String get _baseUrl {
    const fromEnv = String.fromEnvironment(Api.envBaseUrlKey, defaultValue: '');
    if (fromEnv.isNotEmpty) return fromEnv;
    if (Platform.isIOS || Platform.isMacOS) {
      return Api.defaultBaseUrlIosSimulator; // http://localhost:5000
    }
    return Api.defaultBaseUrlAndroidEmulator; // http://10.0.2.2:5000
  }

  Future<void> _fetchCategories() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final uri = Uri.parse('$_baseUrl${Api.categories}');
    final client = HttpClient();

    try {
      final req = await client.getUrl(uri);
      req.headers.set('Accept', 'application/json');
      final resp = await req.close();
      final body = await resp.transform(utf8.decoder).join();

      if (!mounted) return;

      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final decoded = jsonDecode(body);
        final map = (decoded is Map ? decoded : <String, dynamic>{})
            .cast<String, dynamic>();
        final list = (map['items'] as List? ?? [])
            .whereType<Map>()
            .map((m) => CategoryItem.fromJson(m.cast<String, dynamic>()))
            .toList();

        setState(() {
          _all = list;
          _applyFilter();
          _loading = false;
        });
      } else {
        setState(() {
          _error = 'Could not load categories. Please try again.';
          _loading = false;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Network problem. Please check your connection.';
        _loading = false;
      });
    } finally {
      client.close(force: true);
    }
  }

  void _applyFilter() {
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) {
      setState(() => _filtered = List.of(_all));
      return;
    }
    setState(() {
      _filtered = _all.where((c) {
        final inName = c.name.toLowerCase().contains(q);
        final inTypes = c.itemTypes.any((t) => t.toLowerCase().contains(q));
        final inSlug = (c.slug ?? '').toLowerCase().contains(q);
        return inName || inTypes || inSlug;
      }).toList();
    });
  }

  void _onTapCategory(CategoryItem c) {
    // Navigate to your category listing route: '/category/:id'
    // Name must match the GoRoute name in AppRouter (category_listing).
    context.pushNamed('category_listing', pathParameters: {'id': c.id});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: const AppBarPrimary(title: 'Categories'),
      body: RefreshIndicator(
        onRefresh: _fetchCategories,
        color: theme.colorScheme.primary,
        child: _buildBody(theme),
      ),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_loading) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          _SearchSkeleton(),
          SizedBox(height: 12),
          _GridSkeleton(),
        ],
      );
    }

    if (_error != null) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          EmptyState(
            icon: Icons.category_outlined,
            title: 'Can’t load categories',
            message: _error,
            primaryActionLabel: 'Retry',
            onPrimaryAction: _fetchCategories,
          ),
        ],
      );
    }

    final cs = theme.colorScheme;
    final list = _filtered;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: AppTextField.search(
              controller: _searchCtrl,
              hint: 'Search categories',
            ),
          ),
        ),
        if (list.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: EmptyState(
                icon: Icons.search_off_rounded,
                title: 'No matches',
                message: 'Try a different keyword.',
                primaryActionLabel: 'Clear search',
                onPrimaryAction: () {
                  _searchCtrl.clear();
                  _applyFilter();
                },
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.2,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final c = list[index];
                  return _CategoryCard(
                    item: c,
                    surface: theme.cardTheme.color ?? cs.surface,
                    border: cs.outlineVariant,
                    onTap: () => _onTapCategory(c),
                  );
                },
                childCount: list.length,
              ),
            ),
          ),
      ],
    );
  }
}

// =============================================================================
// Data model
// =============================================================================

class CategoryItem {
  final String id;
  final String name;
  final String? slug;
  final List<String> itemTypes;

  const CategoryItem({
    required this.id,
    required this.name,
    this.slug,
    required this.itemTypes,
  });

  factory CategoryItem.fromJson(Map<String, dynamic> json) {
    final types = <String>[];
    final rawTypes = json['item_types'];
    if (rawTypes is List) {
      for (final t in rawTypes) {
        if (t is String) types.add(t);
      }
    }
    return CategoryItem(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      slug: (json['slug'] as String?)?.toString(),
      itemTypes: types,
    );
  }
}

// =============================================================================
// UI widgets
// =============================================================================

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.item,
    required this.surface,
    required this.border,
    this.onTap,
  });

  final CategoryItem item;
  final Color surface;
  final Color border;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Ink(
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _InitialBadge(
                text: item.name,
                bg: cs.primaryContainer,
                fg: cs.onPrimaryContainer,
              ),
              const SizedBox(height: 10),
              Text(
                item.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Wrap(
                spacing: 6,
                runSpacing: -6,
                children: item.itemTypes
                    .take(3)
                    .map(
                      (t) => _ChipMini(
                        label: t,
                        bg: cs.surfaceContainerHighest,
                        fg: cs.onSurfaceVariant,
                        border: cs.outlineVariant,
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InitialBadge extends StatelessWidget {
  const _InitialBadge({
    required this.text,
    required this.bg,
    required this.fg,
  });

  final String text;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    final initial =
        text.trim().isEmpty ? '?' : text.trim().characters.first.toUpperCase();
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: fg,
              fontWeight: FontWeight.w800,
            ),
      ),
    );
  }
}

class _ChipMini extends StatelessWidget {
  const _ChipMini({
    required this.label,
    required this.bg,
    required this.fg,
    required this.border,
  });

  final String label;
  final Color bg;
  final Color fg;
  final Color border;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(999),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: fg,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

// =============================================================================
// Skeletons
// =============================================================================

class _SearchSkeleton extends StatelessWidget {
  const _SearchSkeleton();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 48,
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: cs.outlineVariant),
          ),
        ),
      ],
    );
  }
}

class _GridSkeleton extends StatelessWidget {
  const _GridSkeleton();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 6,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
      ),
      itemBuilder: (_, __) {
        return Container(
          decoration: BoxDecoration(
            color: cs.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: cs.outlineVariant),
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                height: 14,
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              const Spacer(),
              Row(
                children: [
                  _bar(cs, 60),
                  const SizedBox(width: 6),
                  _bar(cs, 40),
                  const SizedBox(width: 6),
                  _bar(cs, 50),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _bar(ColorScheme cs, double w) => Container(
        width: w,
        height: 18,
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(999),
        ),
      );
}
