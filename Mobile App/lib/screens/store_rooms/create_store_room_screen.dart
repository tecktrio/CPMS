import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/inventory_provider.dart';
import '../../widgets/user_profile_avatar.dart';

class CreateStoreRoomScreen extends StatefulWidget {
  const CreateStoreRoomScreen({super.key});

  @override
  State<CreateStoreRoomScreen> createState() => _CreateStoreRoomScreenState();
}

class _CreateStoreRoomScreenState extends State<CreateStoreRoomScreen> {
  final _formKey = GlobalKey<FormState>();
  final _roomCodeController = TextEditingController();
  final _nameController = TextEditingController();
  final _tempController = TextEditingController();
  final _capacityController = TextEditingController(text: '1000');
  final _divisionCountController = TextEditingController(text: '2');

  final List<TextEditingController> _divisionControllers = [
    TextEditingController(text: 'Section A'),
    TextEditingController(text: 'Section B'),
  ];

  bool _isSubmitting = false;

  @override
  void dispose() {
    _roomCodeController.dispose();
    _nameController.dispose();
    _tempController.dispose();
    _capacityController.dispose();
    _divisionCountController.dispose();
    for (final c in _divisionControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _generateDivisions(int count) {
    if (count <= 0 || count > 50) return;
    setState(() {
      for (final c in _divisionControllers) {
        c.dispose();
      }
      _divisionControllers.clear();
      for (int i = 1; i <= count; i++) {
        _divisionControllers.add(TextEditingController(text: 'Section $i'));
      }
    });
  }

  void _addDivision() {
    setState(() {
      final nextNum = _divisionControllers.length + 1;
      _divisionControllers.add(TextEditingController(text: 'Section $nextNum'));
      _divisionCountController.text = _divisionControllers.length.toString();
    });
  }

  void _removeDivision(int index) {
    setState(() {
      _divisionControllers[index].dispose();
      _divisionControllers.removeAt(index);
      _divisionCountController.text = _divisionControllers.length.toString();
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
      roomCode: _roomCodeController.text.trim().toUpperCase(),
      roomName: _nameController.text.trim(),
      temperature: temp,
      totalCapacityUnits:
          double.tryParse(_capacityController.text.trim()) ?? 1000,
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
          backgroundColor: const Color(0xFF0F766E),
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
    required String hintText,
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
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
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
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black, size: 24),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 960),
            child: Row(
              children: const [
                Text(
                  'Create Store Room',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
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
          constraints: const BoxConstraints(maxWidth: 960),
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
                        border: Border.all(color: const Color(0xFFE2E8F0)),
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
                      hintText: 'e.g. Main Cold Store or Dry Store Room 1',
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

                  // Room Code
                  _buildFieldLabel('ROOM CODE *'),
                  TextFormField(
                    controller: _roomCodeController,
                    textCapitalization: TextCapitalization.characters,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                    decoration: _buildInputDecoration(
                      hintText: 'e.g. SR-01 or COLD-01',
                      prefixIcon: const Icon(
                        Icons.tag,
                        size: 20,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Room code is required';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 18),

                  // Temperature & Capacity Row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Temperature (Optional)
                      Expanded(
                        child: Column(
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
                                hintText: 'e.g. -18.0 (blank for ambient)',
                                prefixIcon: const Icon(
                                  Icons.thermostat_outlined,
                                  size: 20,
                                  color: Color(0xFF94A3B8),
                                ),
                              ),
                              validator: (val) {
                                if (val != null &&
                                    val.trim().isNotEmpty &&
                                    double.tryParse(val.trim()) == null) {
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
                                _buildTempPresetChip('Frozen (-18°C)', '-18.0'),
                                _buildTempPresetChip('Chilled (4°C)', '4.0'),
                                _buildTempPresetChip('Ambient', ''),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),
                      // Capacity
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildFieldLabel('TOTAL CAPACITY (KG / UNITS) *'),
                            TextFormField(
                              controller: _capacityController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.black,
                              ),
                              decoration: _buildInputDecoration(
                                hintText: '1000',
                                prefixIcon: const Icon(
                                  Icons.scale_outlined,
                                  size: 20,
                                  color: Color(0xFF94A3B8),
                                ),
                              ),
                              validator: (val) {
                                if (val == null ||
                                    double.tryParse(val.trim()) == null) {
                                  return 'Enter valid capacity';
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
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
                          backgroundColor: Colors.black,
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

                  // Quick Division Generator
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.auto_awesome_outlined,
                          size: 16,
                          color: Color(0xFF64748B),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Auto-generate sections:',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF334155),
                          ),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 50,
                          height: 34,
                          child: TextFormField(
                            controller: _divisionCountController,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                            decoration: InputDecoration(
                              isDense: true,
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 8,
                                horizontal: 6,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(4),
                                borderSide: const BorderSide(
                                  color: Color(0xFFE2E8F0),
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(4),
                                borderSide: const BorderSide(
                                  color: Color(0xFFE2E8F0),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(4),
                                borderSide: const BorderSide(
                                  color: Colors.black,
                                  width: 1.5,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.black,
                            side: const BorderSide(color: Color(0xFFCBD5E1)),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          onPressed: () {
                            final count = int.tryParse(
                                  _divisionCountController.text.trim(),
                                ) ??
                                0;
                            if (count > 0) _generateDivisions(count);
                          },
                          child: const Text(
                            'Generate',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Division List
                  ...List.generate(_divisionControllers.length, (idx) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 13,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Text(
                              '#${idx + 1}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: Colors.black,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextFormField(
                              controller: _divisionControllers[idx],
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.black,
                              ),
                              decoration: _buildInputDecoration(
                                hintText: 'e.g. Rack A, Shelf 1, Zone B',
                                prefixIcon: const Icon(
                                  Icons.grid_view_outlined,
                                  size: 18,
                                  color: Color(0xFF94A3B8),
                                ),
                              ),
                            ),
                          ),
                          if (_divisionControllers.length > 1) ...[
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
                        ],
                      ),
                    );
                  }),

                  const SizedBox(height: 32),
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
              constraints: const BoxConstraints(maxWidth: 960),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
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
