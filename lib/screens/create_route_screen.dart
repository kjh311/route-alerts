import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_places_flutter/google_places_flutter.dart';
import 'package:google_places_flutter/model/prediction.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/design_system.dart';
import '../logic/route_cubit.dart';
import '../models/route_model.dart';
import '../core/constants.dart';

class CreateRouteScreen extends StatefulWidget {
  const CreateRouteScreen({super.key});

  @override
  State<CreateRouteScreen> createState() => _CreateRouteScreenState();
}

class _CreateRouteScreenState extends State<CreateRouteScreen> {
  final TextEditingController _startController = TextEditingController();
  final TextEditingController _endController = TextEditingController();
  
  Prediction? _startPrediction;
  Prediction? _endPrediction;

  TimeOfDay _startTime = const TimeOfDay(hour: 6, minute: 0);
  double _duration = 11.5;
  int _alertLeadTime = 30;

  final List<String> _stops = ['Chicago, IL', 'Des Moines, IA', 'Omaha, NE'];

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => RouteCubit(),
      child: BlocConsumer<RouteCubit, RouteState>(
        listener: (context, state) {
          if (state is RouteSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Route saved & activated!')),
            );
            Navigator.pop(context);
          } else if (state is RouteFailure) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error: ${state.error}')),
            );
          }
        },
        builder: (context, state) {
          return Scaffold(
            appBar: AppBar(
              leading: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back, color: AppDesignSystem.primary),
              ),
              title: const Text('CREATE ROUTE'),
              actions: [
                IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.more_vert, color: Colors.grey),
                ),
              ],
            ),
            body: ListView(
              padding: const EdgeInsets.symmetric(horizontal: AppDesignSystem.marginEdge),
              children: [
                const SizedBox(height: 24),
                // Header
                Text('New Dedicated Route', style: AppDesignSystem.headlineLarge.copyWith(color: AppDesignSystem.primaryVariant)),
                Text('Configure your long-haul parameters', style: AppDesignSystem.bodyMedium.copyWith(color: AppDesignSystem.onSurfaceVariant)),
                const SizedBox(height: AppDesignSystem.gutter),

                // Bento Input Section
                _buildBentoCard(
                  label: 'Starting Point',
                  child: GooglePlaceAutoCompleteTextField(
                    textEditingController: _startController,
                    googleAPIKey: AppConstants.googleApiKey,
                    inputDecoration: _inputDecoration('Enter origin city or terminal', Icons.location_on, AppDesignSystem.secondary),
                    debounceTime: 800,
                    itemClick: (Prediction prediction) {
                      setState(() {
                        _startPrediction = prediction;
                        _startController.text = prediction.description ?? '';
                      });
                    },
                  ),
                ),
                const SizedBox(height: AppDesignSystem.stackGap),
                _buildBentoCard(
                  label: 'Destination',
                  child: GooglePlaceAutoCompleteTextField(
                    textEditingController: _endController,
                    googleAPIKey: AppConstants.googleApiKey,
                    inputDecoration: _inputDecoration('Enter destination city or port', Icons.flag, AppDesignSystem.primary),
                    debounceTime: 800,
                    itemClick: (Prediction prediction) {
                      setState(() {
                        _endPrediction = prediction;
                        _endController.text = prediction.description ?? '';
                      });
                    },
                  ),
                ),
                const SizedBox(height: AppDesignSystem.gutter),

                // Map Preview
                _buildMapPreview(),
                const SizedBox(height: AppDesignSystem.gutter),

                // Time and Duration
                _buildBentoCard(
                  label: 'Shift Start Time',
                  child: InkWell(
                    onTap: () => _selectTime(context),
                    child: Container(
                      height: AppDesignSystem.touchTargetMin,
                      decoration: BoxDecoration(
                        color: AppDesignSystem.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(AppDesignSystem.radiusSmall),
                        border: Border.all(color: AppDesignSystem.outline.withOpacity(0.2)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.schedule, color: AppDesignSystem.primary),
                          const SizedBox(width: 8),
                          Text(
                            _startTime.format(context).toUpperCase(),
                            style: AppDesignSystem.headlineMedium,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppDesignSystem.stackGap),
                _buildBentoCard(
                  label: 'Shift Duration',
                  trailingLabel: '${_duration} Hours',
                  child: Column(
                    children: [
                      Slider(
                        value: _duration,
                        min: 0,
                        max: 14,
                        divisions: 28,
                        onChanged: (v) => setState(() => _duration = v),
                      ),
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('0H', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppDesignSystem.outline)),
                          Text('7H', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppDesignSystem.outline)),
                          Text('14H', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppDesignSystem.outline)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppDesignSystem.gutter),

                // Alert Notification
                _buildBentoCard(
                  label: 'Alert Notification',
                  child: Container(
                    height: AppDesignSystem.touchTargetMin,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: AppDesignSystem.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(AppDesignSystem.radiusSmall),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.notifications_active, color: Colors.orange),
                        const SizedBox(width: 12),
                        const Text('Alert Lead Time', style: TextStyle(fontWeight: FontWeight.w500)),
                        const Spacer(),
                        DropdownButton<int>(
                          value: _alertLeadTime,
                          underline: const SizedBox(),
                          dropdownColor: AppDesignSystem.surfaceContainerHigh,
                          icon: const Icon(Icons.expand_more, size: 18, color: AppDesignSystem.outline),
                          items: [15, 30, 45, 60].map((int value) {
                            return DropdownMenuItem<int>(
                              value: value,
                              child: Text(
                                value == 60 ? '1 hour before' : '$value mins before',
                                style: const TextStyle(color: AppDesignSystem.primary, fontWeight: FontWeight.bold),
                              ),
                            );
                          }).toList(),
                          onChanged: (v) => setState(() => _alertLeadTime = v!),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppDesignSystem.gutter),

                // Route Points List
                _buildBentoCard(
                  label: 'Route Points',
                  headerAction: TextButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.add_circle, size: 18),
                    label: const Text('ADD STOP'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppDesignSystem.secondary,
                      textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                  child: Column(
                    children: _stops.asMap().entries.map((entry) {
                      final index = entry.key;
                      final stop = entry.value;
                      final isFirst = index == 0;
                      final isLast = index == _stops.length - 1;
                      
                      Color accentColor = AppDesignSystem.outline;
                      IconData icon = Icons.more_vert;
                      if (isFirst) {
                        accentColor = AppDesignSystem.secondary;
                        icon = Icons.location_on;
                      } else if (isLast) {
                        accentColor = AppDesignSystem.primary;
                        icon = Icons.flag;
                      }

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppDesignSystem.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(AppDesignSystem.radiusDefault),
                            border: Border(left: BorderSide(color: accentColor, width: 4)),
                          ),
                          child: Row(
                            children: [
                              Icon(icon, color: accentColor),
                              const SizedBox(width: 12),
                              Text(stop, style: AppDesignSystem.bodyLarge),
                              const Spacer(),
                              const Icon(Icons.close, color: Colors.grey, size: 20),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                
                const SizedBox(height: 32),
                // Save Button
                ElevatedButton(
                  onPressed: state is RouteLoading ? null : () => _saveRoute(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppDesignSystem.primaryVariant,
                    minimumSize: const Size.fromHeight(64),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (state is RouteLoading)
                        const CircularProgressIndicator(color: AppDesignSystem.onPrimary)
                      else ...[
                        const Icon(Icons.save),
                        const SizedBox(width: 12),
                        const Text('SAVE & ACTIVATE ROUTE'),
                      ]
                    ],
                  ),
                ),
                const SizedBox(height: 48),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildBentoCard({required String label, String? trailingLabel, required Widget child, Widget? headerAction}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppDesignSystem.surfaceContainer,
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusDefault),
        border: Border.all(color: AppDesignSystem.outline.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label.toUpperCase(), style: AppDesignSystem.labelBold.copyWith(color: AppDesignSystem.outline, letterSpacing: 1.2)),
              if (trailingLabel != null)
                Text(trailingLabel, style: AppDesignSystem.bodyLarge.copyWith(color: AppDesignSystem.primary, fontWeight: FontWeight.bold)),
              if (headerAction != null) headerAction,
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }


  InputDecoration _inputDecoration(String hint, IconData icon, Color iconColor) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, color: iconColor),
    );
  }

  Widget _buildMapPreview() {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Container(
      decoration: BoxDecoration(
        color: AppDesignSystem.surfaceContainer,
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusLarge),
        border: Border.all(color: AppDesignSystem.outline.withOpacity(0.2)),
        image: const DecorationImage(
          image: NetworkImage('https://images.unsplash.com/photo-1524661135-423995f22d0b?auto=format&fit=crop&q=80&w=1000'), // Placeholder for map
          fit: BoxFit.cover,
          opacity: 0.8,
        ),
      ),
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, AppDesignSystem.background.withOpacity(0.8)],
              ),
            ),
          ),
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppDesignSystem.radiusDefault),
              child: BackdropFilter(
                filter: ColorFilter.mode(Colors.black.withOpacity(0.5), BlendMode.darken),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  color: AppDesignSystem.surfaceContainerHigh.withOpacity(0.9),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Estimated Distance', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppDesignSystem.onSurface)),
                          Text('472 mi', style: AppDesignSystem.displayLarge.copyWith(color: AppDesignSystem.primary, height: 1)),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text('Transit Time', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppDesignSystem.onSurface)),
                          Text('7h 45m', style: AppDesignSystem.headlineLarge.copyWith(color: AppDesignSystem.secondary)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }


  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _startTime,
    );
    if (picked != null && picked != _startTime) {
      setState(() {
        _startTime = picked;
      });
    }
  }

  void _saveRoute(BuildContext context) {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please log in first')));
      return;
    }

    final startTimeStr = '${_startTime.hour.toString().padLeft(2, '0')}:${_startTime.minute.toString().padLeft(2, '0')}:00';

    final departureTime = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
      _startTime.hour,
      _startTime.minute,
    );

    final route = RouteModel(
      id: '', // Supabase generates UUID
      userId: userId,
      originName: _startController.text,
      destinationName: _endController.text,
      departureTime: departureTime,
      alertLeadMinutes: _alertLeadTime,
      waypoints: [
        {'name': _startController.text, 'lat': _startPrediction?.lat, 'lng': _startPrediction?.lng},
        {'name': _endController.text, 'lat': _endPrediction?.lat, 'lng': _endPrediction?.lng},
      ],
      routePolyline: '', // TODO: Populate from Google Directions API
      delayMinutes: 0,
      weatherCondition: 'Clear',
      updatedAt: DateTime.now(),
    );

    context.read<RouteCubit>().saveRoute(route);
  }
}
