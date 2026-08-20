import 'package:flutter/material.dart';

enum GameCategory { racing, puzzle, arcade, board, action, cards }

class GameModel {
  final String id;
  final String name;
  final String description;
  final String icon;
  final Color bgColor;
  final Color accentColor;
  final double rating;
  final int players;
  final GameCategory category;
  final int bestScore;
  final String size;
  final int playedCount;
  final double progress;

  const GameModel({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.bgColor,
    required this.accentColor,
    required this.rating,
    required this.players,
    required this.category,
    this.bestScore = 0,
    this.size = '0 MB',
    this.playedCount = 0,
    this.progress = 0,
  });
}

class PlayerModel {
  final String id;
  final String name;
  final String avatar;
  final int level;
  final int xp;
  final int xpToNextLevel;
  final int coins;
  final int gems;
  final int tokens;
  final int gamesPlayed;
  final int highScore;
  final int achievementsCount;

  const PlayerModel({
    required this.id,
    required this.name,
    required this.avatar,
    required this.level,
    required this.xp,
    required this.xpToNextLevel,
    required this.coins,
    required this.gems,
    required this.tokens,
    required this.gamesPlayed,
    required this.highScore,
    required this.achievementsCount,
  });

  double get xpProgress => xp / xpToNextLevel;
}

class LeaderboardEntry {
  final String id;
  final String name;
  final String avatar;
  final int score;
  final int rank;
  final bool isCurrentUser;

  const LeaderboardEntry({
    required this.id,
    required this.name,
    required this.avatar,
    required this.score,
    required this.rank,
    this.isCurrentUser = false,
  });
}

class AchievementModel {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final bool unlocked;
  final DateTime? unlockedAt;

  const AchievementModel({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    this.unlocked = false,
    this.unlockedAt,
  });
}

class RewardItem {
  final int day;
  final String icon;
  final int amount;
  final String type;
  final bool claimed;
  final bool isToday;

  const RewardItem({
    required this.day,
    required this.icon,
    required this.amount,
    required this.type,
    this.claimed = false,
    this.isToday = false,
  });
}

class TaskItem {
  final String id;
  final String title;
  final int current;
  final int target;
  final String rewardIcon;
  final int rewardAmount;
  final bool completed;

  const TaskItem({
    required this.id,
    required this.title,
    required this.current,
    required this.target,
    required this.rewardIcon,
    required this.rewardAmount,
    this.completed = false,
  });

  double get progress => current / target;
}

class AppConstants {
  static const PlayerModel currentPlayer = PlayerModel(
    id: '1',
    name: 'Player One',
    avatar: '👤',
    level: 24,
    xp: 3200,
    xpToNextLevel: 5000,
    coins: 12450,
    gems: 250,
    tokens: 35,
    gamesPlayed: 152,
    highScore: 15230,
    achievementsCount: 28,
  );

  static const List<GameModel> continuePlayingGames = [
    GameModel(
      id: 'bubble',
      name: 'Bubble Shooter',
      description: 'Pop colorful bubbles',
      icon: '🫧',
      bgColor: Color(0xFF1E3A5F),
      accentColor: Color(0xFF60A5FA),
      rating: 4.7,
      players: 8900,
      category: GameCategory.arcade,
      progress: 0.75,
      bestScore: 2450,
    ),
    GameModel(
      id: 'speed',
      name: 'Speed Racer',
      description: 'Drive fast, avoid obstacles',
      icon: '🏎️',
      bgColor: Color(0xFF3B0764),
      accentColor: Color(0xFFA78BFA),
      rating: 4.6,
      players: 12500,
      category: GameCategory.racing,
      progress: 0.6,
      bestScore: 2450,
      size: '85 MB',
      playedCount: 32,
    ),
    GameModel(
      id: 'tictactoe',
      name: 'Tic Tac Toe',
      description: 'Classic strategy game',
      icon: '⭕',
      bgColor: Color(0xFF1A1A2E),
      accentColor: Color(0xFFE879F9),
      rating: 4.5,
      players: 5600,
      category: GameCategory.puzzle,
      progress: 0.4,
      bestScore: 1800,
    ),
  ];

  static const List<GameModel> popularGames = [
    GameModel(
      id: 'fruit',
      name: 'Fruit Ninja',
      description: 'Slice the fruits',
      icon: '🍉',
      bgColor: Color(0xFF3D0A0A),
      accentColor: Color(0xFFF87171),
      rating: 4.6,
      players: 15200,
      category: GameCategory.action,
    ),
    GameModel(
      id: 'ludo',
      name: 'Ludo King',
      description: 'Classic board game',
      icon: '🎲',
      bgColor: Color(0xFF0F172A),
      accentColor: Color(0xFF22D3EE),
      rating: 4.4,
      players: 25000,
      category: GameCategory.board,
    ),
    GameModel(
      id: 'carrom',
      name: 'Carrom Pool',
      description: 'Strike and pocket',
      icon: '🎯',
      bgColor: Color(0xFF291505),
      accentColor: Color(0xFFF59E0B),
      rating: 4.5,
      players: 18700,
      category: GameCategory.board,
    ),
    GameModel(
      id: 'snake',
      name: 'Snake Rush',
      description: 'Eat, grow, survive',
      icon: '🐍',
      bgColor: Color(0xFF052E16),
      accentColor: Color(0xFF4ADE80),
      rating: 4.3,
      players: 9800,
      category: GameCategory.arcade,
    ),
    GameModel(
      id: 'dotsboxes',
      name: 'Dots & Boxes',
      description: 'Capture the most boxes',
      icon: '🔲',
      bgColor: Color(0xFF0F172A),
      accentColor: Color(0xFF22D3EE),
      rating: 4.4,
      players: 7200,
      category: GameCategory.board,
    ),
  ];

  static const List<AchievementModel> achievements = [
    AchievementModel(
      id: 'a1',
      title: 'Champion',
      description: 'Win a tournament',
      icon: Icons.emoji_events_rounded,
      color: Color(0xFFFBBF24),
      unlocked: true,
    ),
    AchievementModel(
      id: 'a2',
      title: 'Sharpshooter',
      description: 'Score 1000 points',
      icon: Icons.center_focus_strong_rounded,
      color: Color(0xFFF87171),
      unlocked: true,
    ),
    AchievementModel(
      id: 'a3',
      title: 'Royal Winner',
      description: 'Reach level 20',
      icon: Icons.workspace_premium_rounded,
      color: Color(0xFFFBBF24),
      unlocked: true,
    ),
    AchievementModel(
      id: 'a4',
      title: 'Guardian',
      description: 'Win 100 games',
      icon: Icons.shield_rounded,
      color: Color(0xFF8B5CF6),
      unlocked: false,
    ),
    AchievementModel(
      id: 'a5',
      title: 'Collector',
      description: 'Collect 10000 coins',
      icon: Icons.diamond_rounded,
      color: Color(0xFF06B6D4),
      unlocked: false,
    ),
  ];

  static const List<AchievementModel> recentAchievements = [
    AchievementModel(
      id: 'r1',
      title: 'Winner',
      description: 'Win 10 games',
      icon: Icons.emoji_events_rounded,
      color: Color(0xFFFBBF24),
      unlocked: true,
    ),
    AchievementModel(
      id: 'r2',
      title: 'Sharpshooter',
      description: 'Score 1000 points',
      icon: Icons.center_focus_strong_rounded,
      color: Color(0xFFF87171),
      unlocked: true,
    ),
    AchievementModel(
      id: 'r3',
      title: 'Champion',
      description: 'Win a tournament',
      icon: Icons.workspace_premium_rounded,
      color: Color(0xFFFBBF24),
      unlocked: true,
    ),
  ];

  static const List<LeaderboardEntry> globalLeaderboard = [
    LeaderboardEntry(
      id: 'l2',
      name: 'Alex',
      avatar: '👨',
      score: 14360,
      rank: 2,
    ),
    LeaderboardEntry(
      id: 'l1',
      name: 'Player One',
      avatar: '👤',
      score: 15230,
      rank: 1,
      isCurrentUser: true,
    ),
    LeaderboardEntry(
      id: 'l3',
      name: 'Sam',
      avatar: '👩',
      score: 9330,
      rank: 3,
    ),
    LeaderboardEntry(
      id: 'l4',
      name: 'Rockstar',
      avatar: '🧑',
      score: 8910,
      rank: 4,
    ),
    LeaderboardEntry(
      id: 'l5',
      name: 'Game Master',
      avatar: '🦸',
      score: 7650,
      rank: 5,
    ),
    LeaderboardEntry(
      id: 'l6',
      name: 'Speedy',
      avatar: '🏃',
      score: 7120,
      rank: 6,
    ),
    LeaderboardEntry(
      id: 'l7',
      name: 'Legend Killer',
      avatar: '⚔️',
      score: 6540,
      rank: 7,
    ),
    LeaderboardEntry(
      id: 'l8',
      name: 'Pro Player',
      avatar: '🎮',
      score: 5230,
      rank: 8,
    ),
  ];

  static const List<RewardItem> dailyRewards = [
    RewardItem(day: 1, icon: '🪙', amount: 100, type: 'coins', claimed: true),
    RewardItem(day: 2, icon: '💎', amount: 10, type: 'gems', claimed: true),
    RewardItem(day: 3, icon: '💎', amount: 30, type: 'gems', claimed: false, isToday: true),
    RewardItem(day: 4, icon: '🪙', amount: 500, type: 'coins', claimed: false),
    RewardItem(day: 5, icon: '🎁', amount: 1, type: 'box', claimed: false),
  ];

  static const List<TaskItem> dailyTasks = [
    TaskItem(
      id: 't1',
      title: 'Play 2 games',
      current: 2,
      target: 2,
      rewardIcon: '🪙',
      rewardAmount: 100,
      completed: true,
    ),
    TaskItem(
      id: 't2',
      title: 'Win 1 game',
      current: 1,
      target: 1,
      rewardIcon: '💎',
      rewardAmount: 5,
      completed: true,
    ),
    TaskItem(
      id: 't3',
      title: 'Score 1000 points',
      current: 750,
      target: 1000,
      rewardIcon: '🪙',
      rewardAmount: 150,
    ),
  ];

  static const List<String> gameModeIcons = ['🤖', '👥', '🏆'];
  static const List<String> gameModes = ['Single Player', 'Multiplayer', 'Tournament'];
  static const List<String> gameModeDescriptions = [
    'Play against AI and beat high scores',
    'Play real-time with players',
    'Compete in tournaments & win big rewards',
  ];
  static const List<Color> gameModeColors = [
    Color(0xFF4338CA),
    Color(0xFF831843),
    Color(0xFF1E3A5F),
  ];
  static const List<Color> gameModeAccents = [
    Color(0xFF818CF8),
    Color(0xFFF472B6),
    Color(0xFFFBBF24),
  ];
}
