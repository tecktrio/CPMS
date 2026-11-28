import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/cpms_page_title.dart';
import 'package:provider/provider.dart';
import '../../providers/inventory_provider.dart';
import '../../widgets/user_profile_avatar.dart';
import '../../widgets/app_footer.dart';

class CreateStoreRoomScreen extends StatefulWidget {
  const CreateStoreRoomScreen({super.key});

  @override
  State<CreateStoreRoomScreen> createState() => _CreateStoreRoomScreenState();
}

class _CreateStoreRoomScreenState extends State<CreateStoreRoomScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _tempController = TextEditingController();

  final List<TextEditingController> _divisionControllers = [];

  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _tempController.dispose();
    for (final c in _divisionControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _addDivision() {
    setState(() {
      _divisionControllers.add(TextEditingController());
    });
  }

  void _removeDivision(int index) {
    setState(() {
      _divisionControllers[index].dispose();
      _divisionControllers.removeAt(index);
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    final inventory = context.read<InventoryProvider>();
    final divisions = _divisionControllers
        .map((c) => c.text.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    final temp = _tempController.text.trim().isNotEmpty
        ? double.tryParse(_tempController.text.trim())
        : null;

    final success = await inventory.createStoreRoom(
      roomName: _nameController.text.trim(),
      description: _descriptionController.text.trim(),
      temperature: temp,
      divisions: divisions,
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Store Room "${_nameController.text.trim()}" created successfully!',
          ),
          backgroundColor: AppTheme.adminStorage,
        ),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            inventory.errorMessage ?? 'Failed to create store room.',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildFieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: Color(0xFF64748B),
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  InputDecoration _buildInputDecoration({
    String? hintText,
    required Widget prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(
        color: Color(0xFF94A3B8),
        fontSize: 14,
        fontWeight: FontWeight.w400,
      ),
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: const BorderSide(color: AppTheme.workspaceBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: const BorderSide(color: AppTheme.workspaceBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: const BorderSide(color: Colors.black, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: const BorderSide(color: Colors.red),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: const BorderSide(color: Colors.red, width: 1.5),
      ),
    );
  }

  Widget _buildTempPresetChip(String label, String value) {
    final isSelected = _tempController.text.trim() == value;
    return InkWell(
      onTap: () {
        setState(() {
          _tempController.text = value;
        });
      },
      borderRadius: BorderRadius.circular(2),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? Colors.black : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(2),
          border: Border.all(
            color: isSelected ? Colors.black : const Color(0xFFE2E8F0),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected ? Colors.white : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth >= 700;

    return Scaffold(
      backgroundColor: AppTheme.adminCanvas,
      appBar: AppBar(
        backgroundColor: AppTheme.adminCanvas,
        foregroundColor: AppTheme.adminInk,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.adminInk, size: 24),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: const CpmsPageTitle(
          'Create store room',
          icon: Icons.warehouse_outlined,
          accent: AppTheme.adminStorage,
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 12),
            child: UserProfileAvatar(),
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFFF1F5F9)),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              isWide ? 28 : 16,
              20,
              isWide ? 28 : 16,
              40,
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Store Room Visual Preview Card (matching CreateItemScreen style)
                  Center(
                    child: Container(
                      width: isWide ? 240 : 200,
                      padding: const EdgeInsets.symmetric(
                        vertical: 20,
                        horizontal: 16,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: AppTheme.workspaceBorder),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: Colors.black,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.warehouse_outlined,
                              color: Colors.white,
                              size: 26,
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Storage Facility',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Cold, Chilled, or Dry Store',
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF94A3B8),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Store Room Name
                  _buildFieldLabel('STORE ROOM NAME *'),
                  TextFormField(
                    controller: _nameController,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                    decoration: _buildInputDecoration(
                      prefixIcon: const Icon(
                        Icons.meeting_room_outlined,
                        size: 20,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Store Room name is required';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 18),

                  // Description (Optional)
                  _buildFieldLabel('DESCRIPTION (OPTIONAL)'),
                  TextFormField(
                    controller: _descriptionController,
                    maxLines: 2,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                    decoration: _buildInputDecoration(
                      prefixIcon: const Icon(
                        Icons.notes_outlined,
                        size: 20,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Temperature (Optional)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildFieldLabel('TEMPERATURE (°C) (OPTIONAL)'),
                      TextFormField(
                        controller: _tempController,
                        keyboardType:
                            const TextInputType.numberWithOptions(
                          signed: true,
                          decimal: true,
                        ),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                        decoration: _buildInputDecoration(
                          prefixIcon: const Icon(
                            Icons.thermostat_outlined,
                            size: 20,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                        validator: (val) {
                          if (val != null &&
                              val.trim().isNotEmpty &&
                              double.tryParse(val.trim())?.isFinite != true) {
                            return 'Enter a valid number';
                          }
                          return null;
                        },
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _buildTempPresetChip('-18 °C', '-18.0'),
                          _buildTempPresetChip('4 °C', '4.0'),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Divisions & Sections Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'DIVISIONS & SECTIONS',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF64748B),
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${_divisionControllers.length} sections defined (racks, shelves, or zones)',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF94A3B8),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.adminStorage,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        onPressed: _addDivision,
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text(
                          'Add Section',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Division List
                  ...List.generate(_divisionControllers.length, (idx) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _divisionControllers[idx],
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.black,
                              ),
                              decoration: _buildInputDecoration(
                                hintText: 'Section name',
                                prefixIcon: const Icon(
                                  Icons.grid_view_outlined,
                                  size: 18,
                                  color: Color(0xFF94A3B8),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Color(0xFFEF4444),
                              size: 20,
                            ),
                            onPressed: () => _removeDivision(idx),
                            tooltip: 'Remove Division',
                          ),
                        ],
                      ),
                    );
                  }),

                  const AppFooter(topPadding: 16, bottomPadding: 24),
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
          ),
          child: Center(
            heightFactor: 1.0,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.adminStorage,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  onPressed: _isSubmitting ? null : _submit,
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check, size: 20, color: Colors.white),
                            SizedBox(width: 8),
                            Text(
                              'Create Store Room',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
