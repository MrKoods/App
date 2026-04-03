import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'models/history_entry.dart';
import 'models/task.dart';
import 'screens/auth_gate.dart';
import 'screens/home_screen.dart';
import 'screens/list_screen.dart';
import 'screens/history_screen.dart';
import 'screens/rewards_screen.dart';
import 'screens/progress_screen.dart';
import 'screens/add_task_screen.dart';
import 'screens/friends_screen.dart';
import 'screens/shared_checklists_screen.dart';
import 'services/auth_service.dart';
import 'services/firestore_service.dart';
import 'services/focus_lock_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await AuthService().initializeAuthPersistence();
  await FocusLockService.instance.initialize();

  runApp(const MicroWinsApp());
}

class MicroWinsApp extends StatelessWidget {
  const MicroWinsApp({super.key});

  @override
  Widget build(BuildContext context) {
    const Color backgroundColor = Color(0xFF090B10);
    const Color surfaceColor = Color(0xFF121826);
    const Color accentColor = Color(0xFF55E6C1);
    const Color secondaryAccent = Color(0xFFFFC857);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MicroWins',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: backgroundColor,
        colorScheme: const ColorScheme.dark(
          primary: accentColor,
          secondary: secondaryAccent,
          surface: surfaceColor,
        ),
        canvasColor: backgroundColor,
        appBarTheme: const AppBarTheme(
          backgroundColor: backgroundColor,
          foregroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
          shadowColor: Colors.transparent,
        ),
        cardColor: surfaceColor,
        snackBarTheme: const SnackBarThemeData(
          backgroundColor: surfaceColor,
          contentTextStyle: TextStyle(color: Colors.white),
          behavior: SnackBarBehavior.floating,
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Color(0xFF101522),
          selectedItemColor: accentColor,
          unselectedItemColor: Colors.white70,
          showUnselectedLabels: true,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: accentColor,
            foregroundColor: backgroundColor,
            textStyle: const TextStyle(fontWeight: FontWeight.w700),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: secondaryAccent,
          foregroundColor: Colors.black,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: surfaceColor,
          labelStyle: const TextStyle(color: Colors.white70),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Colors.white24),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: accentColor, width: 1.4),
          ),
        ),
      ),
      home: const AuthGate(),
    );
  }
}

class MainNavigation extends StatefulWidget {
  final ValueNotifier<int>? tabIndexNotifier;

  const MainNavigation({super.key, this.tabIndexNotifier});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  final FirestoreService _firestoreService = FirestoreService();
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    widget.tabIndexNotifier?.addListener(_handleExternalTabChange);
    unawaited(_firestoreService.ensureStreakProtectionState());
  }

  @override
  void didUpdateWidget(covariant MainNavigation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tabIndexNotifier == widget.tabIndexNotifier) {
      return;
    }

    oldWidget.tabIndexNotifier?.removeListener(_handleExternalTabChange);
    widget.tabIndexNotifier?.addListener(_handleExternalTabChange);
  }

  @override
  void dispose() {
    widget.tabIndexNotifier?.removeListener(_handleExternalTabChange);
    super.dispose();
  }

  void _handleExternalTabChange() {
    final int? nextIndex = widget.tabIndexNotifier?.value;
    if (nextIndex == null || nextIndex == _selectedIndex || !mounted) {
      return;
    }

    setState(() {
      _selectedIndex = nextIndex;
    });
  }

  Future<void> _redeemReward(String rewardId) async {
    final RewardRedemptionResult result = await _firestoreService.redeemReward(
      rewardId: rewardId,
    );

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.message),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _useSkipTodayToken() async {
    final bool consumed = await _firestoreService.useSkipTodayToken();
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          consumed
              ? 'Skip token used. Today is streak-safe.'
              : 'No skip tokens available.',
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _onItemTapped(int index) {
    if (widget.tabIndexNotifier?.value != index) {
      widget.tabIndexNotifier?.value = index;
    }

    setState(() {
      _selectedIndex = index;
    });
  }

  void _openAddTaskScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddTaskScreen()),
    );
  }

  void _openProgressScreen(Map<String, dynamic>? userData) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProgressScreen(initialUserData: userData),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _firestoreService.getUserStream(),
      builder: (context, userSnapshot) {
        if (!userSnapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final Map<String, dynamic>? userData = userSnapshot.data!.data();
        final int coins = (userData?['coins'] as num?)?.toInt() ?? 0;
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _firestoreService.getTasksStream(),
          builder: (context, taskSnapshot) {
            if (!taskSnapshot.hasData) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            final List<Task> tasks = taskSnapshot.data!.docs.map((doc) {
              return Task.fromFirestore(doc.id, doc.data());
            }).toList();

            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _firestoreService.getHistoryStream(),
              builder: (context, historySnapshot) {
                if (!historySnapshot.hasData) {
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }

                final List<HistoryEntry> history = historySnapshot.data!.docs
                    .map<HistoryEntry>(
                      (doc) => HistoryEntry.fromFirestore(doc.id, doc.data()),
                    )
                    .toList();

                final List<Widget> pages = [
                  HomeScreen(
                    tasks: tasks,
                    coins: coins,
                    onNavigateTab: _onItemTapped,
                  ),
                  ListScreen(tasks: tasks, onNavigateTab: _onItemTapped),
                  HistoryScreen(history: history),
                  RewardsScreen(
                    coins: coins,
                    userData: userData ?? const <String, dynamic>{},
                    onRedeemReward: (rewardId) async {
                      await _redeemReward(rewardId);
                    },
                    onUseSkipToday: _useSkipTodayToken,
                  ),
                  const FriendsScreen(),
                  const SharedListScreen(),
                ];

                return Scaffold(
                  appBar: AppBar(
                    title: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: 'MICRO',
                            style: GoogleFonts.audiowide(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.9,
                              color: const Color(0xFF55E6C1),
                            ),
                          ),
                          TextSpan(
                            text: 'wins',
                            style: GoogleFonts.audiowide(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.9,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    actions: [
                      IconButton(
                        icon: const Icon(Icons.query_stats),
                        tooltip: 'Progress',
                        onPressed: () => _openProgressScreen(userData),
                      ),
                      IconButton(
                        icon: const Icon(Icons.logout),
                        onPressed: () async {
                          await AuthService().logout();
                        },
                      ),
                    ],
                  ),
                  body: pages[_selectedIndex],
                  floatingActionButton: _selectedIndex < 2
                      ? FloatingActionButton(
                          onPressed: _openAddTaskScreen,
                          child: const Icon(Icons.add),
                        )
                      : null,
                  bottomNavigationBar: BottomNavigationBar(
                    currentIndex: _selectedIndex,
                    onTap: _onItemTapped,
                    type: BottomNavigationBarType.fixed,
                    items: const [
                      BottomNavigationBarItem(
                        icon: Icon(Icons.home),
                        label: 'Home',
                      ),
                      BottomNavigationBarItem(
                        icon: Icon(Icons.checklist),
                        label: 'My List',
                      ),
                      BottomNavigationBarItem(
                        icon: Icon(Icons.history),
                        label: 'History',
                      ),
                      BottomNavigationBarItem(
                        icon: Icon(Icons.emoji_events),
                        label: 'Rewards',
                      ),
                      BottomNavigationBarItem(
                        icon: Icon(Icons.people_rounded),
                        label: 'Friends',
                      ),
                      BottomNavigationBarItem(
                        icon: Icon(Icons.move_to_inbox_rounded),
                        label: 'Shared',
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
