import 'package:flutter/material.dart';
import 'package:nscgschedule/main.dart';
import 'package:nscgschedule/login.dart';
import 'package:nscgschedule/settings_page.dart';
import 'package:nscgschedule/timetable.dart';
import 'package:nscgschedule/exam_timetable.dart';
import 'package:nscgschedule/exam_details.dart';
import 'package:go_router/go_router.dart';
import 'package:nscgschedule/settings.dart';

final GoRouter routerController = GoRouter(
  routes: <RouteBase>[
    GoRoute(
      path: '/',
      builder: (BuildContext context, GoRouterState state) {
        return LoadingScreen();
      },
    ),
    GoRoute(
      path: '/login',
      builder: (BuildContext context, GoRouterState state) {
        return Login();
      },
    ),
    GoRoute(
      path: '/Timetable',
      builder: (BuildContext context, GoRouterState state) {
        return TimetableScreen();
      },
    ),
    GoRoute(
      path: '/exams',
      builder: (BuildContext context, GoRouterState state) {
        return ExamTimetableScreen();
      },
    ),
    GoRoute(
      path: '/exams/details',
      builder: (BuildContext context, GoRouterState state) {
        return ExamDetailsScreen();
      },
    ),
    GoRoute(
      path: '/settings',
      builder: (BuildContext context, GoRouterState state) {
        return SettingsPage();
      },
    ),
  ],
  redirect: (BuildContext context, GoRouterState state) async {
    final timetable = await settings.getMap('timetable');
    final isAuthenticated = timetable.toString() != '{}';
    final currentPath = state.uri.path;

    switch (currentPath) {
      case '/':
        if (!isAuthenticated) return '/login';
        if (isAuthenticated) return '/Timetable';
        break;

      case '/login':
        if (isAuthenticated) return '/Timetable';
        return null;

      default:
        if (isAuthenticated) return null;
        return '/';
    }
    return null;
  },
);
