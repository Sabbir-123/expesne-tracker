import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../core/theme/app_theme.dart';
import '../controllers/transactions_controller.dart';
import '../controllers/voice_expense_controller.dart';
import '../models/transaction_model.dart';
import '../services/firebase_transaction_service.dart';
import 'package:fl_chart/fl_chart.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(transactionStatsProvider);
    final transactionsAsync = ref.watch(transactionsStreamProvider);

    ref.listen<VoiceExpenseState>(voiceExpenseProvider, (previous, next) {
      if ((previous?.transcript != next.transcript && next.transcript.startsWith('Success:')) || 
          (previous?.error == '' && next.error.isNotEmpty)) {
        
        String msg = next.error.isNotEmpty 
          ? next.error 
          : "Added \$\${next.transcript.split(':')[1]} \${next.transcript.split(':')[2]}";

        Color toastColor = AppTheme.success;
        if (next.error.isNotEmpty) {
           if (msg.contains("Couldn't understand")) {
              toastColor = Colors.orangeAccent; // not red
           } else {
              toastColor = AppTheme.danger; // transcript empty / permissions issue
           }
        }

        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white)),
          backgroundColor: toastColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          margin: const EdgeInsets.only(bottom: 120, left: 20, right: 20),
        ));
      }
    });

    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      body: Stack(
        children: [
          // Background soft radial glows
          Positioned(
            top: -100,
            left: -50,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.primaryBlue.withOpacity(0.15),
              ),
              child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50), child: const SizedBox()),
            ),
          ),
          Positioned(
            bottom: -50,
            right: -50,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.accentPurple.withOpacity(0.1),
              ),
              child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 60, sigmaY: 60), child: const SizedBox()),
            ),
          ),
          
          SafeArea(
            bottom: false,
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(child: _buildTopBar(context)),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
                    child: _buildHeroCard(context, stats),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _buildQuickActionsRow(context),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 30)),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Recent Activity', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                        Text('See All', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.primaryBlue)),
                      ],
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 16)),
                transactionsAsync.when(
                  data: (transactions) {
                    if (transactions.isEmpty) {
                      return SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(60.0),
                          child: Center(
                            child: Column(
                              children: [
                                Icon(Icons.inbox_rounded, size: 80, color: Colors.white.withOpacity(0.1)),
                                const SizedBox(height: 20),
                                const Text('No expenses yet', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 8),
                                const Text('Tap the AI Orb to speak your first transaction.', style: TextStyle(color: Colors.white54), textAlign: TextAlign.center),
                              ]
                            ),
                          ),
                        ),
                      );
                    }
                    return SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                            child: _buildPremiumTransactionCard(context, transactions[index], ref)
                              .animate().fade(delay: (index * 50).ms).slideY(begin: 0.1),
                          );
                        },
                        childCount: transactions.length,
                      ),
                    );
                  },
                  loading: () => SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(60.0),
                      child: Center(
                        child: Column(
                          children: [
                            const CircularProgressIndicator(),
                            const SizedBox(height: 16),
                            Text('Loading dashboard...', style: TextStyle(color: Colors.white.withOpacity(0.5))),
                          ]
                        )
                      ),
                    ),
                  ),
                  error: (e, _) => SliverToBoxAdapter(child: Center(child: Text('Error: \$e', style: const TextStyle(color: Colors.white)))),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 180)), // Nav bar space
              ],
            ),
          ),
          
          // AI Voice Overlay Panel (Only visible when active)
          _buildVoiceOverlayPanel(context, ref),

          // Premium Floating Nav
          Align(
            alignment: Alignment.bottomCenter,
            child: _buildFloatingBottomNav(context, ref),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const CircleAvatar(
            radius: 20,
            backgroundImage: NetworkImage('https://i.pravatar.cc/150?img=11'),
          ),
          const Text(
            'SpeakSpend',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
          Row(
            children: [
              Icon(Icons.dark_mode_outlined, color: Colors.white.withOpacity(0.8), size: 24),
              const SizedBox(width: 16),
              Icon(Icons.notifications_none_rounded, color: Colors.white.withOpacity(0.8), size: 24),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildHeroCard(BuildContext context, Map<String, double> stats) {
    return Container(
      height: 190,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          colors: [
            AppTheme.darkCard.withOpacity(0.9),
            AppTheme.darkCard.withOpacity(0.6),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryBlue.withOpacity(0.15),
            blurRadius: 30,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Total Balance', style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 8),
                      Text(
                        NumberFormat.currency(symbol: '\$').format(stats['balance']), 
                        style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w900, letterSpacing: -1.5)
                      ).animate().shimmer(duration: 2.seconds, color: Colors.white12),
                      const Spacer(),
                      Row(
                        children: [
                          _buildPill(Icons.south_west_rounded, AppTheme.success, '\$${NumberFormat.compact().format(stats['income'])}'),
                          const SizedBox(width: 12),
                          _buildPill(Icons.north_east_rounded, AppTheme.danger, '\$${NumberFormat.compact().format(stats['expense'])}'),
                        ],
                      )
                    ],
                  ),
                ),
                // Sparkline
                SizedBox(
                  width: 80,
                  height: 50,
                  child: LineChart(
                    LineChartData(
                      gridData: FlGridData(show: false),
                      titlesData: FlTitlesData(show: false),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                        LineChartBarData(
                          spots: const [
                            FlSpot(0, 3), FlSpot(1, 4), FlSpot(2, 2.5), FlSpot(3, 5), FlSpot(4, 4), FlSpot(5, 6)
                          ],
                          isCurved: true,
                          color: AppTheme.primaryBlue,
                          barWidth: 3,
                          isStrokeCapRound: true,
                          dotData: FlDotData(show: false),
                          belowBarData: BarAreaData(
                            show: true,
                            color: AppTheme.primaryBlue.withOpacity(0.15),
                          )
                        )
                      ],
                    ),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    ).animate().fade(duration: 800.ms).slideY(begin: -0.05);
  }

  Widget _buildPill(IconData icon, Color color, String amount) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(amount, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildQuickActionsRow(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildActionBtn(Icons.arrow_upward_rounded, 'Expense'),
        _buildActionBtn(Icons.arrow_downward_rounded, 'Income'),
        _buildActionBtn(Icons.document_scanner_rounded, 'Receipt'),
        _buildActionBtn(Icons.bar_chart_rounded, 'Analytics'),
      ],
    ).animate().fade(delay: 200.ms).slideX(begin: -0.05);
  }

  Widget _buildActionBtn(IconData icon, String label) {
    return Column(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: AppTheme.darkCard,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withOpacity(0.05)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ]
          ),
          child: Icon(icon, color: Colors.white, size: 24),
        ),
        const SizedBox(height: 8),
        Text(label, style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildPremiumTransactionCard(BuildContext context, TransactionModel t, WidgetRef ref) {
    bool isIncome = t.type == 'income';
    final formatter = DateFormat('MMM d, h:mm a');
    return Dismissible(
      key: Key(t.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppTheme.danger,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      onDismissed: (_) {
         ref.read(firebaseTransactionServiceProvider).deleteTransaction(t.id);
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.darkCard.withOpacity(0.4),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.03)),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: (isIncome ? AppTheme.success : AppTheme.danger).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(_getCategoryIcon(t.category), color: isIncome ? AppTheme.success : AppTheme.danger),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.note.isNotEmpty ? t.note : t.category.toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)),
                  const SizedBox(height: 4),
                  Text(formatter.format(t.createdAt), style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
                ],
              ),
            ),
            Text(
              '${isIncome ? '+' : '-'}\$${t.amount.toStringAsFixed(0)}',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    final lower = category.toLowerCase();
    if (lower.contains('food') || lower.contains('coffee')) return Icons.coffee_rounded;
    if (lower.contains('travel') || lower.contains('uber')) return Icons.local_taxi_rounded;
    if (lower.contains('shop')) return Icons.shopping_bag_rounded;
    if (lower.contains('salary') || lower.contains('income')) return Icons.account_balance_wallet_rounded;
    return Icons.receipt_long_rounded;
  }

  Widget _buildVoiceOverlayPanel(BuildContext context, WidgetRef ref) {
    final voiceState = ref.watch(voiceExpenseProvider);

    if (!voiceState.isListening && !voiceState.isProcessing && voiceState.transcript.isEmpty) {
      return const SizedBox.shrink();
    }

    return Positioned(
      top: 0, left: 0, right: 0, bottom: 0,
      child: GestureDetector(
        onTap: () {
          // If tapping outside while success or error, do nothing or force dismiss?
        },
        child: Container(
          color: AppTheme.darkBackground.withOpacity(0.9),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    voiceState.transcript.isEmpty 
                      ? (voiceState.isProcessing ? 'Processing AI...' : 'Listening...') 
                      : voiceState.transcript,
                    style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w700, height: 1.2, letterSpacing: -1),
                    textAlign: TextAlign.center,
                  ).animate().fade().scale(),
                ),
                const SizedBox(height: 180),
              ],
            ),
          ),
        ),
      ).animate().fade(duration: 200.ms),
    );
  }

  Widget _buildFloatingBottomNav(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24, left: 24, right: 24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(40),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            height: 70,
            decoration: BoxDecoration(
              color: AppTheme.darkCard.withOpacity(0.8),
              borderRadius: BorderRadius.circular(40),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10))
              ]
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildNavIcon(Icons.home_rounded, true),
                    _buildNavIcon(Icons.insert_chart_rounded, false),
                    const SizedBox(width: 80), // Gap for FAB
                    _buildNavIcon(Icons.account_balance_wallet_rounded, false),
                    _buildNavIcon(Icons.settings_rounded, false),
                  ],
                ),
                // Premium AI Orb Button
                Positioned(
                  top: -25, // Elevate above nav bar
                  child: _buildAIOrbButton(ref),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavIcon(IconData icon, bool isActive) {
    return IconButton(
      icon: Icon(icon, size: 28, color: isActive ? Colors.white : Colors.white.withOpacity(0.4)),
      onPressed: () {},
    );
  }

  Widget _buildAIOrbButton(WidgetRef ref) {
    final voiceState = ref.watch(voiceExpenseProvider);
    final voiceNotifier = ref.read(voiceExpenseProvider.notifier);

    bool isListening = voiceState.isListening;
    bool isProcessing = voiceState.isProcessing;

    return GestureDetector(
      onTap: () {
        if (isListening) {
           voiceNotifier.stopListeningAndProcess();
        } else if (!isProcessing) {
           voiceNotifier.startListening();
        }
      },
      child: Container(
        width: 84,
        height: 84,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: isListening
                ? [AppTheme.danger, AppTheme.danger.withOpacity(0.5)]
                : [AppTheme.primaryBlue, AppTheme.accentPurple],
          ),
          boxShadow: [
            BoxShadow(
              color: isListening ? AppTheme.danger.withOpacity(0.6) : AppTheme.accentPurple.withOpacity(0.4),
              blurRadius: isListening ? 30 : 20,
              spreadRadius: isListening ? 10 : 2,
            )
          ],
          border: Border.all(color: Colors.white.withOpacity(0.2), width: 1.5),
        ),
        child: Center(
          child: isProcessing 
              ? const SizedBox(width: 30, height: 30, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
              : Icon(
                  isListening ? Icons.stop_rounded : Icons.graphic_eq_rounded, 
                  color: Colors.white, 
                  size: 36
                )
                  .animate(onPlay: (c) => isListening ? c.repeat(reverse: true) : null)
                  .scale(begin: const Offset(1,1), end: const Offset(1.2,1.2)),
        ),
      ).animate(onPlay: (c) => c.repeat(reverse: true)).scale(begin: const Offset(1,1), end: const Offset(1.05, 1.05)),
    );
  }
}
