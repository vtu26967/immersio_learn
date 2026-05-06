import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import 'package:ar_flutter_plugin_plus/ar_flutter_plugin_plus.dart';
import 'package:ar_flutter_plugin_plus/datatypes/config_planedetection.dart';
import 'package:ar_flutter_plugin_plus/datatypes/node_types.dart';
import 'package:ar_flutter_plugin_plus/managers/ar_anchor_manager.dart';
import 'package:ar_flutter_plugin_plus/managers/ar_location_manager.dart';
import 'package:ar_flutter_plugin_plus/managers/ar_object_manager.dart';
import 'package:ar_flutter_plugin_plus/managers/ar_session_manager.dart';
import 'package:ar_flutter_plugin_plus/models/ar_node.dart';
import 'package:vector_math/vector_math_64.dart' hide Colors;
import '../../constants/app_colors.dart';
import '../../models/lesson_model.dart';
import '../feedback/feedback_screen.dart';

class ArcoreViewScreen extends StatefulWidget {
  final LessonModel lesson;

  const ArcoreViewScreen({super.key, required this.lesson});

  @override
  State<ArcoreViewScreen> createState() => _ArcoreViewScreenState();
}

class _ArcoreViewScreenState extends State<ArcoreViewScreen>
    with SingleTickerProviderStateMixin {
  bool _autoRotate = true;
  late TabController _tabController;

  // ── AR State ───────────────────────────────────────────────────────────────
  ARSessionManager? _arSessionManager;
  ARObjectManager? _arObjectManager;
  ARNode? _arNode;
  bool _arModelPlaced = false;
  bool _arLoading = true;

  // ── AR Transform State ─────────────────────────────────────────────────────
  double _modelScale = 0.3;
  double _baseScale = 0.3;
  double _rotationX = 0.0; // up/down
  double _rotationY = 0.0; // left/right
  Offset _lastFocalPoint = Offset.zero;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    if (_arNode != null) {
      _arObjectManager?.removeNode(_arNode!);
    }
    _arSessionManager?.dispose();
    _tabController.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // AR CALLBACKS
  // ═══════════════════════════════════════════════════════════════════════════

  void _onARViewCreated(
    ARSessionManager arSessionManager,
    ARObjectManager arObjectManager,
    ARAnchorManager arAnchorManager,
    ARLocationManager arLocationManager,
  ) {
    _arSessionManager = arSessionManager;
    _arObjectManager = arObjectManager;

    // Initialize AR session — hide planes since we place directly
    _arSessionManager!.onInitialize(
      showFeaturePoints: false,
      showPlanes: false,
      showWorldOrigin: false,
      showAnimatedGuide: false,
      handleTaps: false,
      handlePans: false,
      handleRotation: false,
    );

    _arObjectManager!.onInitialize();

    // Wait for ARCore to establish stable SLAM tracking before placing
    // This prevents the "object follows user walking" 3DoF tracking glitch.
    _arSessionManager!.onTrackingStateChanged = (state, reason) {
      if (state == "TRACKING" && !_arModelPlaced && _arLoading && mounted) {
        _placeModel();
      }
    };

    // Fallback: place after 2.5 seconds if tracking state callback is missed
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (!_arModelPlaced && _arLoading && mounted) {
        _placeModel();
      }
    });
  }

  /// Place the 3D model directly in front of the camera (no anchor needed).
  /// The model is placed at z = -1.5 (1.5 meters ahead of the camera).
  Future<void> _placeModel() async {
    if (_arObjectManager == null) return;

    setState(() {
      _arLoading = true;
    });

    try {
      final node = ARNode(
        type: NodeType.localGLTF2,
        uri: widget.lesson.modelUrl,
        scale: Vector3(_modelScale, _modelScale, _modelScale),
        position: Vector3(0.0, -0.5, -1.5),
        rotation: Vector4(0, 1, 0, 0),
        name: 'lesson_model_${DateTime.now().millisecondsSinceEpoch}',
      );

      final success = await _arObjectManager!.addNode(node);

      if (success == true) {
        _arNode = node;
        if (mounted) {
          setState(() {
            _arModelPlaced = true;
            _arLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() => _arLoading = false);
          _showMessage('Could not load model. Try again.', isError: true);
        }
      }
    } catch (e) {
      debugPrint('[AR] Error placing model: $e');
      if (mounted) {
        setState(() => _arLoading = false);
        _showMessage('Error: ${e.toString()}', isError: true);
      }
    }
  }

  /// Remove and re-place the model
  void _resetModel() {
    if (_arNode != null) {
      _arObjectManager?.removeNode(_arNode!);
      _arNode = null;
    }
    setState(() {
      _arModelPlaced = false;
      _arLoading = true;
      _modelScale = 0.3;
      _baseScale = 0.3;
      _rotationX = 0.0;
      _rotationY = 0.0;
    });
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _placeModel();
    });
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // GESTURE HANDLERS — Update node transforms via transformNotifier
  // ═══════════════════════════════════════════════════════════════════════════

  void _updateRotation() {
    if (_arNode == null) return;
    final qY = Quaternion.axisAngle(Vector3(0, 1, 0), _rotationY);
    final qX = Quaternion.axisAngle(Vector3(1, 0, 0), _rotationX);
    _arNode!.rotationFromQuaternion = qY * qX;
  }

  void _onScaleStart(ScaleStartDetails details) {
    _baseScale = _modelScale;
    _lastFocalPoint = details.focalPoint;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    if (_arNode == null) return;

    // ── Pinch to scale ────────────────────────────────────────────────────
    if (details.pointerCount >= 2) {
      _modelScale = (_baseScale * details.scale).clamp(0.05, 5.0);
      _arNode!.scale = Vector3(_modelScale, _modelScale, _modelScale);
    }

    // ── Single finger drag to rotate ──────────────────────────────────────
    if (details.pointerCount == 1) {
      final dx = details.focalPoint.dx - _lastFocalPoint.dx;
      final dy = details.focalPoint.dy - _lastFocalPoint.dy;
      
      _rotationY += dx * 0.015; // convert pixels to radians
      _rotationX += dy * 0.015;
      _lastFocalPoint = details.focalPoint;

      _updateRotation();
    }

    setState(() {}); // update UI hints
  }

  // ── Buttons (alternative to gestures) ───────────────────────────────────

  void _scaleUp() {
    if (_arNode == null) return;
    _modelScale = (_modelScale * 1.2).clamp(0.05, 5.0);
    _arNode!.scale = Vector3(_modelScale, _modelScale, _modelScale);
    setState(() {});
  }

  void _scaleDown() {
    if (_arNode == null) return;
    _modelScale = (_modelScale / 1.2).clamp(0.05, 5.0);
    _arNode!.scale = Vector3(_modelScale, _modelScale, _modelScale);
    setState(() {});
  }

  void _rotateLeft() {
    if (_arNode == null) return;
    _rotationY -= math.pi / 6; // 30 degrees
    _updateRotation();
    setState(() {});
  }

  void _rotateRight() {
    if (_arNode == null) return;
    _rotationY += math.pi / 6; // 30 degrees
    _updateRotation();
    setState(() {});
  }

  void _rotateUp() {
    if (_arNode == null) return;
    _rotationX -= math.pi / 6; // 30 degrees
    _updateRotation();
    setState(() {});
  }

  void _rotateDown() {
    if (_arNode == null) return;
    _rotationX += math.pi / 6; // 30 degrees
    _updateRotation();
    setState(() {});
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════════════════════════════════════

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ── Info Bottom Sheet ────────────────────────────────────────────────────────

  void _showInfo() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                widget.lesson.title,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.primary.withOpacity(0.3),
                  ),
                ),
                child: Text(
                  widget.lesson.difficulty,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                widget.lesson.description,
                style: const TextStyle(
                  fontSize: 16,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(Iconsax.category, color: AppColors.primary, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    widget.lesson.category,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(widget.lesson.title),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Iconsax.arrow_left_2),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorSize: TabBarIndicatorSize.label,
          tabs: const [
            Tab(icon: Icon(Iconsax.d_cube_scan), text: '3D View'),
            Tab(icon: Icon(Iconsax.camera), text: 'AR View'),
          ],
        ),
      ),
      extendBodyBehindAppBar: true,
      body: TabBarView(
        controller: _tabController,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _build3DViewTab(),
          _buildARViewTab(),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TAB 1: 3D Model Viewer (model_viewer_plus — always reliable)
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _build3DViewTab() {
    return Stack(
      children: [
        ModelViewer(
          backgroundColor: const Color(0xFF0A0A1A),
          src: widget.lesson.modelUrl,
          alt: 'A 3D model of ${widget.lesson.title}',
          ar: false,
          autoRotate: _autoRotate,
          autoRotateDelay: 0,
          rotationPerSecond: '30deg',
          cameraControls: true,
          disableZoom: false,
          interactionPrompt: InteractionPrompt.auto,
          shadowIntensity: 1.0,
          shadowSoftness: 1.0,
          exposure: 1.0,
        ),

        // Gesture Hint
        Positioned(
          top: 140,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.swipe, color: Colors.white70, size: 16),
                  SizedBox(width: 6),
                  Text(
                    'Drag to rotate  •  Pinch to zoom',
                    style: TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Bottom Controls
        Positioned(
          bottom: 40,
          left: 20,
          right: 20,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildControlButton(
                icon: _autoRotate ? Iconsax.pause : Iconsax.play,
                label: _autoRotate ? 'Pause' : 'Rotate',
                onTap: () => setState(() => _autoRotate = !_autoRotate),
              ),
              const SizedBox(width: 24),
              _buildControlButton(
                icon: Iconsax.info_circle,
                label: 'Info',
                onTap: _showInfo,
              ),
              const SizedBox(width: 24),
              _buildControlButton(
                icon: Iconsax.star1,
                label: 'Feedback',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const FeedbackScreen(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TAB 2: AR Camera View (ar_flutter_plugin_plus)
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildARViewTab() {
    return Stack(
      children: [
        // ── AR Camera ───────────────────────────────────────────────────────
        ARView(
          onARViewCreated: _onARViewCreated,
          planeDetectionConfig: PlaneDetectionConfig.horizontalAndVertical,
        ),

        // ── Gesture Overlay ─────────────────────────────────────────────────
        // We place this transparent overlay OVER the ARView so the platform
        // view doesn't absorb the touches, making pinch & swipe actually work.
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onScaleStart: _onScaleStart,
            onScaleUpdate: _onScaleUpdate,
            child: Container(color: Colors.transparent),
          ),
        ),

        // ── Loading Overlay ───────────────────────────────────────────────
        if (_arLoading)
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.5),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Stabilizing AR Tracking...',
                      style: const TextStyle(
                          color: Colors.white, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
          ),

        // ── Hint text ─────────────────────────────────────────────────────
        if (_arModelPlaced && !_arLoading)
          Positioned(
            top: 140,
            left: 16,
            right: 16,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle,
                        color: Colors.greenAccent, size: 16),
                    SizedBox(width: 6),
                    Text(
                      'Swipe to rotate  •  Pinch to resize  •  Use buttons below',
                      style:
                          TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
          ),

        // ── Scale / Rotate Buttons (right side) ──────────────────────────
        if (_arModelPlaced && !_arLoading)
          Positioned(
            right: 16,
            top: MediaQuery.of(context).size.height * 0.30,
            child: Column(
              children: [
                _buildMiniButton(Icons.add, _scaleUp),
                const SizedBox(height: 8),
                _buildMiniButton(Icons.remove, _scaleDown),
                const SizedBox(height: 16),
                _buildMiniButton(Icons.keyboard_arrow_up, _rotateUp),
                const SizedBox(height: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildMiniButton(Icons.keyboard_arrow_left, _rotateLeft),
                    const SizedBox(width: 8),
                    _buildMiniButton(Icons.keyboard_arrow_right, _rotateRight),
                  ],
                ),
                const SizedBox(height: 8),
                _buildMiniButton(Icons.keyboard_arrow_down, _rotateDown),
              ],
            ),
          ),

        // ── Bottom Control Buttons ────────────────────────────────────────
        Positioned(
          bottom: 40,
          left: 20,
          right: 20,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildControlButton(
                icon: Iconsax.refresh,
                label: 'Reset',
                onTap: _resetModel,
              ),
              const SizedBox(width: 24),
              _buildControlButton(
                icon: Iconsax.info_circle,
                label: 'Info',
                onTap: _showInfo,
              ),
              const SizedBox(width: 24),
              _buildControlButton(
                icon: Iconsax.star1,
                label: 'Feedback',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const FeedbackScreen(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SHARED WIDGETS
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildMiniButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: AppColors.surface.withOpacity(0.85),
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.primary.withOpacity(0.4)),
        ),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface.withOpacity(0.8),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.primary.withOpacity(0.5)),
            ),
            child: Icon(icon, color: Colors.white),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ],
      ),
    );
  }
}