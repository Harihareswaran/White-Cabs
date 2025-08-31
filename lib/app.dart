import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/home_screen.dart';
import 'screens/vehicle/vehicle_list_screen.dart';
import 'screens/driver/driver_list_screen.dart';
import 'services/database_service.dart';
import 'services/storage_service.dart';
import 'services/sms_service.dart';

class ChezliyanCabsApp extends StatelessWidget {
  const ChezliyanCabsApp({Key? key}) : super(key: key);

  ThemeData _buildAppTheme() {
    return ThemeData.light(useMaterial3: false).copyWith(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF0B103E),
        brightness: Brightness.light,
      ),
      cardTheme: CardThemeData(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          padding: WidgetStateProperty.all(
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => DatabaseService()),
        Provider(create: (_) => StorageService()),
        Provider(create: (_) => SmsService()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'White Cabs',
        theme: _buildAppTheme(),
        home: const AppHome(),
      ),
    );
  }
}

class AppHome extends StatefulWidget {
  const AppHome({Key? key}) : super(key: key);

  @override
  _AppHomeState createState() => _AppHomeState();
}

class _AppHomeState extends State<AppHome> {
  int _selectedIndex = 0;

  static final List<Widget> _screens = [
    const HomeScreen(),
    const VehicleListScreen(),
    const DriverListScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _selectedIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _selectedIndex != 0) {
          setState(() {
            _selectedIndex = 0;
          });
        }
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFF0B103E),
          foregroundColor: Colors.white,
          title: Row(
            children: [
              Image.asset(
                'assets/logo.jpg',
                height: 50,
                fit: BoxFit.contain,
              ),
              const SizedBox(width: 8),
              const Text(
                'White Cabs',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'Powered by Codecat Solutions',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 7.5,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ),
          ],
        ),
        body: _screens[_selectedIndex],
        bottomNavigationBar: BottomNavigationBar(
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.directions_car),
              label: 'Vehicles',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person),
              label: 'Drivers',
            ),
          ],
          currentIndex: _selectedIndex,
          selectedItemColor: Colors.blue[700],
          onTap: _onItemTapped,
        ),
      ),
    );
  }
}
