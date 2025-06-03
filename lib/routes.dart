import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart' as home;
import 'screens/construction_screen.dart';
import 'screens/add_work_screen.dart';
import 'screens/group_chat_page.dart';
import 'screens/blog_screen.dart' as blog;
import 'screens/documents_screen.dart';
import 'screens/report_issue_screen.dart';
import 'screens/games_screen.dart' as games;
import 'screens/bulletin_board_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/security_screen.dart';
import 'screens/alarm_screen.dart';
import 'screens/notifications_screen.dart' as user_notifications;
import 'screens/create_blog_screen.dart' as create_blog;
import 'screens/profile_screen.dart';
import 'screens/create_location_screen.dart';
import 'screens/marketplace_screen.dart';
import 'screens/add_article_screen.dart';
import 'screens/blog_details_screen.dart';
import 'screens/parking_community_screen.dart';
import 'screens/servicer_dashboard_screen.dart';
import 'screens/location_details_screen.dart';
import 'screens/snow_cleaning_screen.dart';
import 'screens/create_snow_cleaning_schedule_screen.dart';

Route<dynamic>? generateRoute(RouteSettings settings) {
  final args = settings.arguments as Map<String, dynamic>?;

  switch (settings.name) {
    case '/':
    case '/login':
      return MaterialPageRoute(builder: (context) => const LoginScreen());
    case '/home':
      return _buildRoute(
          args,
          (context) => home.HomeScreen(
                username: args?['username'] ?? '',
                countryId: args?['countryId'] ?? '',
                cityId: args?['cityId'] ?? '',
                locationId: args?['locationId'] ?? '',
              ));
    case '/locationDetails':
      return _buildRoute(
          args,
          (context) => LocationDetailsScreen(
                countryId: args?['countryId'] ?? '',
                cityId: args?['cityId'] ?? '',
                locationId: args?['locationId'] ?? '',
                username: args?['username'] ?? '',
                displayName: args?['displayName'] ?? 'Unnamed Location',
                isFunnyMode: args?['isFunnyMode'] ?? false,
                locationAdmin: args?['locationAdmin'] ?? false,
              ));
    case '/construction':
      return _buildRoute(
          args,
          (context) => ConstructionScreen(
                username: args?['username'] ?? '',
                locationId: args?['locationId'] ?? '',
                countryId: args?['countryId'] ?? '',
                cityId: args?['cityId'] ?? '',
              ));
    case '/addWork':
      return _buildRoute(
          args,
          (context) => AddWorkScreen(
                username: args?['username'] ?? '',
                locationId: args?['locationId'] ?? '',
                countryId: args?['countryId'] ?? '',
                cityId: args?['cityId'] ?? '',
              ));
    case '/chat':
      return _buildRoute(
          args,
          (context) => GroupChatPage(
                locationId: args?['locationId'] ?? '',
                countryId: args?['countryId'] ?? '',
                cityId: args?['cityId'] ?? '',
              ));
    case '/blog':
      return _buildRoute(
          args,
          (context) => blog.BlogScreen(
                username: args?['username'] ?? '',
                locationId: args?['locationId'] ?? '',
                countryId: args?['countryId'] ?? '',
                cityId: args?['cityId'] ?? '',
              ));
    case '/documents':
      return _buildRoute(
          args,
          (context) => DocumentsScreen(
                username: args?['username'] ?? '',
                locationId: args?['locationId'] ?? '',
                countryId: args?['countryId'] ?? '',
                cityId: args?['cityId'] ?? '',
              ));
    case '/report':
      return _buildRoute(
          args,
          (context) => ReportIssueScreen(
                username: args?['username'] ?? '',
                locationId: args?['locationId'] ?? '',
                countryId: args?['countryId'] ?? '',
                cityId: args?['cityId'] ?? '',
              ));
    case '/games':
      return _buildRoute(
          args,
          (context) => games.GamesScreen(
                username: args?['username'] ?? '',
                locationId: args?['locationId'] ?? '',
                countryId: args?['countryId'] ?? '',
                cityId: args?['cityId'] ?? '',
              ));
    case '/bulletin':
      return _buildRoute(
          args,
          (context) => BulletinBoardScreen(
                username: args?['username'] ?? '',
                locationId: args?['locationId'] ?? '',
                countryId: args?['countryId'] ?? '',
                cityId: args?['cityId'] ?? '',
              ));
    case '/settings':
      return _buildRoute(
          args,
          (context) => SettingsScreen(
                username: args?['username'] ?? '',
                locationId: args?['locationId'] ?? '',
                countryId: args?['countryId'] ?? '',
                cityId: args?['cityId'] ?? '',
                locationAdmin: false, // Dodajte ovo
              ));
    case '/security':
      return _buildRoute(
        args,
        (context) => SecurityScreen(
          username: args?['username'] ?? '',
          locationId: args?['locationId'] ?? '',
          countryId: args?['countryId'] ?? '',
          cityId: args?['cityId'] ?? '',
          locationAdmin: args?['locationAdmin'] ?? false, // Dodano
        ),
      );

    case '/alarm':
      return _buildRoute(
          args,
          (context) => AlarmScreen(
                username: args?['username'] ?? '',
                locationId: args?['locationId'] ?? '',
                countryId: args?['countryId'] ?? '',
                cityId: args?['cityId'] ?? '',
              ));
    case '/notifications':
      return _buildRoute(
          args,
          (context) => user_notifications.NotificationsScreen(
                username: args?['username'] ?? '',
                locationId: args?['locationId'] ?? '',
                countryId: args?['countryId'] ?? '',
                cityId: args?['cityId'] ?? '',
              ));
    case '/createBlog':
      return _buildRoute(
          args,
          (context) => create_blog.CreateBlogScreen(
                username: args?['username'] ?? '',
                locationId: args?['locationId'] ?? '',
                countryId: args?['countryId'] ?? '',
                cityId: args?['cityId'] ?? '',
              ));
    case '/profile':
      return _buildRoute(
          args,
          (context) => ProfileScreen(
                username: args?['username'] ?? '',
                countryId: args?['countryId'] ?? '',
                cityId: args?['cityId'] ?? '',
                locationId: args?['locationId'] ?? '',
                locationName: args?['locationName'] ??
                    'Unnamed Location', // Dodano locationName
              ));
    case '/createLocation':
      return _buildRoute(
          args,
          (context) => CreateLocationScreen(
                username: args?['username'] ?? '',
                countryId: args?['countryId'] ?? '',
                cityId: args?['cityId'] ?? '',
                locationId: args?['locationId'] ?? '',
              ));
    case '/marketplace':
      return _buildRoute(
          args,
          (context) => MarketplaceScreen(
                username: args?['username'] ?? '',
                locationId: args?['locationId'] ?? '',
                countryId: args?['countryId'] ?? '',
                cityId: args?['cityId'] ?? '',
              ));
    case '/add_article':
      return _buildRoute(
          args,
          (context) => AddArticleScreen(
                locationId: args?['locationId'] ?? '',
                categoryField: args?['categoryField'] ?? '',
                countryId: args?['countryId'] ?? '',
                cityId: args?['cityId'] ?? '',
                onSave: args?['onSave'],
              ));
    case '/blog_details':
      return _buildRoute(
          args,
          (context) => BlogDetailsScreen(
                blog: args?['blog'] ?? '',
                username: args?['username'] ?? '',
                countryId: args?['countryId'] ?? '',
                cityId: args?['cityId'] ?? '',
                locationId: args?['locationId'] ?? '',
                locationAdmin: args?['locationAdmin'] ?? false,
              ));
    case '/snow_cleaning':
      return MaterialPageRoute(
        builder: (context) => SnowCleaningScreen(
          countryId: args?['countryId'] ?? '',
          cityId: args?['cityId'] ?? '',
          locationId: args?['locationId'] ?? '',
          username: args?['username'] ?? '',
        ),
      );

    case '/create_snow_cleaning_schedule':
      return MaterialPageRoute(
        builder: (context) => CreateSnowCleaningScheduleScreen(
          countryId: args?['countryId'] ?? '',
          cityId: args?['cityId'] ?? '',
          locationId: args?['locationId'] ?? '',
        ),
      );

    case '/create_snow_cleaning_schedule':
      return _buildRoute(
        args,
        (context) => CreateSnowCleaningScheduleScreen(
          countryId: args?['countryId'] ?? '',
          cityId: args?['cityId'] ?? '',
          locationId: args?['locationId'] ?? '',
        ),
      );

    case '/parking_community':
      return _buildRoute(
        args,
        (context) => ParkingCommunityScreen(
          countryId: args?['countryId'] ?? '',
          cityId: args?['cityId'] ?? '',
          locationId: args?['locationId'] ?? '',
          username: args?['username'] ?? '',
          locationAdmin: args?['locationAdmin'] ?? false,
        ),
      );

    case '/servicer_dashboard':
      return _buildRoute(
          args,
          (context) => ServicerDashboardScreen(
                username: args?['username'] ?? '',
              ));
    default:
      return _errorRoute();
  }
}

MaterialPageRoute<dynamic> _buildRoute(
    Map<String, dynamic>? args, WidgetBuilder builder) {
  return MaterialPageRoute(builder: builder);
}

MaterialPageRoute<dynamic> _errorRoute() {
  return MaterialPageRoute(
    builder: (context) => Scaffold(
      appBar: AppBar(
        title: const Text('Error'),
      ),
      body: const Center(
        child: Text('Page not found'),
      ),
    ),
  );
}
