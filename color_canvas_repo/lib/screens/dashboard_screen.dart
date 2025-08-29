// lib/screens/dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/project_service.dart';
import '../services/firebase_service.dart';
import '../services/analytics_service.dart';
import '../models/project.dart';
import '../widgets/auth_dialog.dart';
import 'roller_screen.dart';
import 'explore_screen.dart';
import 'color_story_wizard_screen.dart';
import 'visualizer_screen.dart';
import 'login_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    // Track dashboard opened
    AnalyticsService.instance.logDashboardOpened();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _checkReduceMotion();
  }

  void _checkReduceMotion() {
    _reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
  }

  Stream<List<ProjectDoc>> _getProjectsStream() {
    return ProjectService.myProjectsStream();
  }

  void _showSignInPrompt() {
    showDialog(
      context: context,
      builder: (context) => AuthDialog(
        onAuthSuccess: () {
          Navigator.pop(context);
          setState(() {}); // Refresh to show projects
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final titleStyle = theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800);
    final subtle = theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface.withOpacity(.6));

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: Semantics(
        label: 'Dashboard screen',
        child: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              sliver: SliverToBoxAdapter(
                child: Row(
                  children: [
                    Text('Colrvia', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                    const Spacer(),
                    Semantics(
                      label: 'Explore inspirations',
                      button: true,
                      child: IconButton(
                        icon: const Icon(Icons.settings_outlined),
                        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ExploreScreen())),
                        tooltip: 'Explore',
                        iconSize: 24,
                        constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Hero CTA
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              sliver: SliverToBoxAdapter(child: _HeroStartCard(titleStyle: titleStyle, subtle: subtle, reduceMotion: _reduceMotion)),
            ),

            // Funnel diagram
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              sliver: SliverToBoxAdapter(child: _FunnelDiagram()),
            ),

            // Active projects
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              sliver: SliverToBoxAdapter(
                child: Semantics(
                  header: true,
                  label: 'Your Color Stories section',
                  child: Text('Your Color Stories', style: titleStyle),
                ),
              ),
            ),

            StreamBuilder<List<ProjectDoc>>(
              stream: _getProjectsStream(),
              builder: (context, snapshot) {
                // Show sign-in prompt if not authenticated
                if (FirebaseService.currentUser == null) {
                  return SliverToBoxAdapter(child: _SignInPromptCard(onSignIn: _showSignInPrompt));
                }
                
                final projects = snapshot.data ?? const <ProjectDoc>[];
                if (snapshot.connectionState == ConnectionState.waiting && projects.isEmpty) {
                  return SliverToBoxAdapter(child: _ProjectsSkeleton());
                }
                if (projects.isEmpty) {
                  return SliverToBoxAdapter(child: _EmptyProjects());
                }
                return SliverList.separated(
                  itemCount: projects.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) => Semantics(
                    label: 'Project ${projects[i].title}, ${projects[i].funnelStage.name} stage',
                    button: true,
                    child: _ProjectCard(projects[i]),
                  ),
                );
              },
            ),

            // Helpful pills
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
              sliver: SliverToBoxAdapter(child: _HelpfulPills()),
            ),
          ],
        ),
      ),
      ),
    );
  }
}

class _HeroStartCard extends StatelessWidget {
  const _HeroStartCard({required this.titleStyle, required this.subtle, required this.reduceMotion});
  final TextStyle? titleStyle;
  final TextStyle? subtle;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      label: 'Start a new color story. Build from scratch or explore inspirations',
      container: true,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withOpacity(.6),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Semantics(
          header: true,
          label: 'Start a Color Story',
          child: Text('Start a Color Story', style: titleStyle),
        ),
        const SizedBox(height: 6),
        Semantics(
          label: 'Build from scratch or explore inspirations. You can always change your mind later.',
          child: Text('Build from scratch or explore inspirations. You can always change your mind later.', style: subtle),
        ),
        const SizedBox(height: 16),
        Semantics(
          label: 'Choose how to start your color story',
          child: Wrap(spacing: 12, runSpacing: 12, children: [
            _ActionChipBig(
              icon: Icons.palette_outlined,
              label: 'Build',
              semanticLabel: 'Build palette from scratch',
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RollerScreen())),
            ),
            _ActionChipBig(
              icon: Icons.explore_outlined,
              label: 'Explore',
              semanticLabel: 'Explore color inspirations',
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ExploreScreen())),
            ),
          ]),
        ),
      ]),
      ),
    );
  }
}

class _FunnelDiagram extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Row(
      children: [
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: const [
              // Build -> Story -> Visualize -> Share
              _FunnelChip(label: 'Build', icon: Icons.palette_outlined, active: true),
              Icon(Icons.arrow_forward_ios, size: 14),
              _FunnelChip(label: 'Story', icon: Icons.menu_book_outlined),
              Icon(Icons.arrow_forward_ios, size: 14),
              _FunnelChip(label: 'Visualize', icon: Icons.chair_outlined),
              Icon(Icons.arrow_forward_ios, size: 14),
              _FunnelChip(label: 'Share', icon: Icons.ios_share_outlined),
            ]),
          ),
        ),
        const SizedBox(width: 8),
        Semantics(
          label: 'How it works help',
          button: true,
          child: InkWell(
            onTap: () => _showHowItWorksSheet(context),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: theme.colorScheme.outline.withOpacity(.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.help_outline,
                size: 16,
                color: theme.colorScheme.onSurface.withOpacity(.7),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showHowItWorksSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => const _HowItWorksSheet(),
    );
  }
}

class _FunnelChip extends StatelessWidget {
  const _FunnelChip({required this.label, required this.icon, this.active = false});
  final String label;
  final IconData icon;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      label: '$label stage${active ? ', currently active' : ''}',
      child: Chip(
        avatar: Icon(icon, size: 16),
        label: Text(label),
        side: active ? BorderSide(color: theme.colorScheme.primary) : null,
        backgroundColor: active ? theme.colorScheme.primaryContainer : theme.colorScheme.surfaceContainerHighest.withOpacity(.5),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}

class _ProjectCard extends StatelessWidget {
  const _ProjectCard(this.p);
  final ProjectDoc p;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = {
      FunnelStage.build: 'Building',
      FunnelStage.story: 'Story drafted',
      FunnelStage.visualize: 'Visualizer ready',
      FunnelStage.share: 'Shared'
    }[p.funnelStage]!;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      minVerticalPadding: 12,
      title: Text(p.title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
      subtitle: Text(status),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        switch (p.funnelStage) {
          case FunnelStage.build:
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RollerScreen()));
            break;
          case FunnelStage.story:
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ColorStoryWizardScreen()));
            break;
          case FunnelStage.visualize:
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => const VisualizerScreen()));
            break;
          case FunnelStage.share:
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => const VisualizerScreen()));
            break;
        }
      },
    );
  }
}

class _EmptyProjects extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(.5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('No Color Stories yet', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        const Text('Start by building a palette or exploring inspirations.'),
        const SizedBox(height: 12),
        Wrap(spacing: 8, children: [
          Semantics(
            label: 'Build palette from scratch',
            button: true,
            child: ActionChip(
              label: const Text('Build'),
              avatar: const Icon(Icons.palette_outlined),
              materialTapTargetSize: MaterialTapTargetSize.padded,
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RollerScreen())),
            ),
          ),
          Semantics(
            label: 'Explore color inspirations',
            button: true,
            child: ActionChip(
              label: const Text('Explore'),
              avatar: const Icon(Icons.explore_outlined),
              materialTapTargetSize: MaterialTapTargetSize.padded,
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ExploreScreen())),
            ),
          ),
        ])
      ]),
    );
  }
}

class _HelpfulPills extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: const [
        _Pill('How it Works', Icons.route_outlined),
        _Pill('Color Stories', Icons.collections_bookmark_outlined),
        _Pill('Top Projects', Icons.favorite_outline),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill(this.label, this.icon);
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      label: '$label information',
      button: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withOpacity(.6),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 16),
          const SizedBox(width: 8),
          Text(label),
        ]),
      ),
    );
  }
}

class _ActionChipBig extends StatelessWidget {
  const _ActionChipBig({required this.icon, required this.label, required this.onTap, this.semanticLabel});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      label: semanticLabel ?? label,
      button: true,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon),
            const SizedBox(width: 8),
            Text(label, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          ]),
        ),
      ),
    );
  }
}

class _HowItWorksSheet extends StatelessWidget {
  const _HowItWorksSheet();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Icon(
                  Icons.route_outlined,
                  color: theme.colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  'How it Works',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                  tooltip: 'Close',
                ),
              ],
            ),
          ),
          
          // Steps
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              children: [
                _HowItWorksStep(
                  icon: Icons.palette_outlined,
                  title: 'Build',
                  description: 'Create your perfect color palette',
                  isFirst: true,
                ),
                _HowItWorksStep(
                  icon: Icons.menu_book_outlined,
                  title: 'Story',
                  description: 'Generate AI-powered color stories',
                ),
                _HowItWorksStep(
                  icon: Icons.chair_outlined,
                  title: 'Visualize',
                  description: 'See colors in real room settings',
                ),
                _HowItWorksStep(
                  icon: Icons.ios_share_outlined,
                  title: 'Share',
                  description: 'Export and share your creations',
                  isLast: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HowItWorksStep extends StatelessWidget {
  const _HowItWorksStep({
    required this.icon,
    required this.title,
    required this.description,
    this.isFirst = false,
    this.isLast = false,
  });
  
  final IconData icon;
  final String title;
  final String description;
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return IntrinsicHeight(
      child: Row(
        children: [
          // Icon and connector line
          SizedBox(
            width: 40,
            child: Column(
              children: [
                if (!isFirst)
                  Container(
                    width: 2,
                    height: 12,
                    color: theme.colorScheme.outline.withOpacity(.3),
                  ),
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    icon,
                    size: 18,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: theme.colorScheme.outline.withOpacity(.3),
                    ),
                  ),
              ],
            ),
          ),
          
          const SizedBox(width: 16),
          
          // Content
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                top: isFirst ? 0 : 12,
                bottom: isLast ? 0 : 12,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(.7),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SignInPromptCard extends StatelessWidget {
  const _SignInPromptCard({required this.onSignIn});
  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withOpacity(.3),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.primary.withOpacity(.2),
          width: 1,
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(
          children: [
            Icon(
              Icons.account_circle_outlined,
              color: theme.colorScheme.primary,
              size: 24,
            ),
            const SizedBox(width: 12),
            Text(
              'Sign in to see your Color Stories',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text('Track your projects and sync across devices.'),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: onSignIn,
          icon: const Icon(Icons.login),
          label: const Text('Sign In'),
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: theme.colorScheme.onPrimary,
          ),
        ),
      ]),
    );
  }
}

class _ProjectsSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: List.generate(3, (index) => Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withOpacity(.3),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title skeleton
              Container(
                height: 16,
                width: 120 + (index * 20).toDouble(),
                decoration: BoxDecoration(
                  color: theme.colorScheme.outline.withOpacity(.2),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(height: 8),
              // Subtitle skeleton
              Container(
                height: 14,
                width: 80,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outline.withOpacity(.15),
                  borderRadius: BorderRadius.circular(7),
                ),
              ),
            ],
          ),
        )),
      ),
    );
  }
}