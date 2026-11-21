import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/department_provider.dart';
import '../../providers/tenant_provider.dart';
import '../../widgets/user_profile_avatar.dart';

class UpdateUserDepartmentsScreen extends StatefulWidget {
  final TenantUserModel? existingUser;

  const UpdateUserDepartmentsScreen({super.key, this.existingUser});

  @override
  State<UpdateUserDepartmentsScreen> createState() =>
      _UpdateUserDepartmentsScreenState();
}

class _UpdateUserDepartmentsScreenState
    extends State<UpdateUserDepartmentsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _userSearchController = TextEditingController();
  final _searchController = TextEditingController();
  String? _selectedDepartmentId;
  String _searchQuery = '';
  bool _isSubmitting = false;

  List<GlobalUserSuggestion> _userSuggestions = [];
  bool _isSearchingUsers = false;
  Timer? _debounceTimer;
  GlobalUserSuggestion? _selectedSuggestion;

  bool get isEditing => widget.existingUser != null;

  @override
  void initState() {
    super.initState();
    if (isEditing) {
      if (widget.existingUser!.departmentIds.isNotEmpty) {
        _selectedDepartmentId = widget.existingUser!.departmentIds.first;
      }
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TenantProvider>().loadTenantDepartments();
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _userSearchController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String val) {
    if (isEditing) return;
    _debounceTimer?.cancel();
    final trimmed = val.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _userSuggestions = [];
        _isSearchingUsers = false;
        _selectedSuggestion = null;
      });
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 250), () async {
      setState(() => _isSearchingUsers = true);
      final results =
          await context.read<DepartmentProvider>().searchGlobalUsers(trimmed);
      if (!mounted) return;
      setState(() {
        _userSuggestions = results;
        _isSearchingUsers = false;
      });
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDepartmentId == null || _selectedDepartmentId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please select exactly 1 department to assign this staff user.',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final deptProvider = context.read<DepartmentProvider>();
    bool success;

    if (isEditing) {
      success = await deptProvider.updateTenantUser(
        userId: widget.existingUser!.userId,
        departmentIds: [_selectedDepartmentId!],
      );
    } else {
      final username = _selectedSuggestion != null
          ? _selectedSuggestion!.userName
          : (!_userSearchController.text.contains('@')
              ? _userSearchController.text.trim().toLowerCase()
              : null);
      final email = _selectedSuggestion != null
          ? _selectedSuggestion!.emailAddress
          : (_userSearchController.text.contains('@')
              ? _userSearchController.text.trim().toLowerCase()
              : null);

      success = await deptProvider.addTenantUser(
        userName: username,
        emailAddress: email,
        departmentIds: [_selectedDepartmentId!],
      );
    }

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (success) {
      final displayName = isEditing
          ? (widget.existingUser!.fullName.isNotEmpty
              ? widget.existingUser!.fullName
              : widget.existingUser!.userName.isNotEmpty
                  ? '@${widget.existingUser!.userName}'
                  : widget.existingUser!.emailAddress)
          : (_selectedSuggestion != null
              ? '@${_selectedSuggestion!.userName}'
              : _userSearchController.text.trim());

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEditing
                ? 'Staff user $displayName department reassigned successfully!'
                : 'Staff user $displayName added to department successfully!',
          ),
          backgroundColor: const Color(0xFF0F766E),
        ),
      );
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            deptProvider.errorMessage ?? 'Failed to update user departments.',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tenant = context.watch<TenantProvider>();
    final allDepartments = tenant.tenantDepartments;

    final filteredDepartments = allDepartments.where((d) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return d.departmentName.toLowerCase().contains(q) ||
          d.description.toLowerCase().contains(q);
    }).toList();

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
        centerTitle: true,
        title: Text(
          isEditing ? 'Reassign Department' : 'Add Staff Member',
          style: const TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 8),
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Top Card: Assign Departments
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFAFAFA),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFF1F5F9)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.manage_accounts_outlined,
                        size: 24,
                        color: Color(0xFF16A34A),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isEditing ? 'Reassign Department' : 'Assign Department',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isEditing
                                ? 'Select one of the system fixed departments to reassign this staff user.'
                                : 'Select one of the system fixed departments to assign to this new staff user.',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // 2. Staff Member / User Search
              if (isEditing) ...[
                Row(
                  children: const [
                    Text(
                      'STAFF MEMBER',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF64748B),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: const Color(0xFF0F766E),
                        child: Text(
                          (widget.existingUser!.fullName.isNotEmpty
                                  ? widget.existingUser!.fullName[0]
                                  : widget.existingUser!.userName.isNotEmpty
                                      ? widget.existingUser!.userName[0]
                                      : 'U')
                              .toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.existingUser!.fullName.isNotEmpty
                                  ? widget.existingUser!.fullName
                                  : 'Staff Member',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              widget.existingUser!.userName.isNotEmpty
                                  ? '@${widget.existingUser!.userName} • ${widget.existingUser!.emailAddress}'
                                  : widget.existingUser!.emailAddress,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.lock,
                              size: 12,
                              color: Color(0xFF64748B),
                            ),
                            SizedBox(width: 4),
                            Text(
                              'User Fixed',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF475569),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ] else if (_selectedSuggestion != null) ...[
                Row(
                  children: const [
                    Text(
                      'SELECTED STAFF MEMBER',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF64748B),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF86EFAC)),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: const Color(0xFF16A34A),
                        child: Text(
                          (_selectedSuggestion!.fullName.isNotEmpty
                                  ? _selectedSuggestion!.fullName[0]
                                  : _selectedSuggestion!.userName.isNotEmpty
                                      ? _selectedSuggestion!.userName[0]
                                      : 'U')
                              .toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _selectedSuggestion!.fullName.isNotEmpty
                                        ? _selectedSuggestion!.fullName
                                        : _selectedSuggestion!.userName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFDCFCE7),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'Selected',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF16A34A),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '@${_selectedSuggestion!.userName} • ${_selectedSuggestion!.emailAddress}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.close,
                          size: 20,
                          color: Color(0xFF64748B),
                        ),
                        tooltip: 'Change User',
                        onPressed: () {
                          setState(() {
                            _selectedSuggestion = null;
                            _userSearchController.clear();
                            _userSuggestions = [];
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ] else ...[
                Row(
                  children: const [
                    Text(
                      'SEARCH STAFF USER (USERNAME OR EMAIL)',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF64748B),
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      ' *',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFEF4444),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _userSearchController,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search by @username or user@example.com',
                    hintStyle: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: Colors.black, width: 1.5),
                    ),
                    prefixIcon: const Icon(
                      Icons.search,
                      size: 20,
                      color: Color(0xFF94A3B8),
                    ),
                    suffixIcon: _userSearchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _userSearchController.clear();
                              _onSearchChanged('');
                            },
                          )
                        : null,
                  ),
                  onChanged: _onSearchChanged,
                  validator: (val) {
                    if (_selectedSuggestion == null &&
                        (val == null || val.trim().isEmpty)) {
                      return 'Please search and select a staff user';
                    }
                    return null;
                  },
                ),
                if (_isSearchingUsers)
                  Padding(
                    padding: const EdgeInsets.only(top: 8, left: 4),
                    child: Row(
                      children: const [
                        SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF0F766E),
                          ),
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Searching global registered users...',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (_userSuggestions.isNotEmpty && _selectedSuggestion == null)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    constraints: const BoxConstraints(maxHeight: 220),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x0A000000),
                          blurRadius: 8,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      itemCount: _userSuggestions.length,
                      separatorBuilder: (context, index) =>
                          const Divider(height: 1, color: Color(0xFFF1F5F9)),
                      itemBuilder: (context, idx) {
                        final s = _userSuggestions[idx];
                        return ListTile(
                          dense: true,
                          leading: CircleAvatar(
                            radius: 16,
                            backgroundColor: s.isAvailable
                                ? const Color(0xFF0F766E)
                                : const Color(0xFF94A3B8),
                            child: Text(
                              (s.fullName.isNotEmpty
                                      ? s.fullName[0]
                                      : s.userName.isNotEmpty
                                          ? s.userName[0]
                                          : 'U')
                                  .toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Text(
                            s.fullName.isNotEmpty ? s.fullName : s.userName,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          subtitle: Text(
                            '@${s.userName} • ${s.emailAddress}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: s.isInCurrentTenant
                                  ? const Color(0xFFFEF3C7)
                                  : s.isInOtherTenant
                                      ? const Color(0xFFFEE2E2)
                                      : const Color(0xFFDCFCE7),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              s.isInCurrentTenant
                                  ? 'Already Member'
                                  : s.isInOtherTenant
                                      ? (s.otherTenantName != null
                                          ? 'In: ${s.otherTenantName}'
                                          : 'In Another Org')
                                      : 'Available',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: s.isInCurrentTenant
                                    ? const Color(0xFFB45309)
                                    : s.isInOtherTenant
                                        ? const Color(0xFFB91C1C)
                                        : const Color(0xFF15803D),
                              ),
                            ),
                          ),
                          onTap: () {
                            if (s.isInCurrentTenant) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'This user is already a member of this organization.',
                                  ),
                                  backgroundColor: Colors.orange,
                                ),
                              );
                              return;
                            }
                            if (s.isInOtherTenant) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'This user is already a member of ${s.otherTenantName ?? "another organization"}. Users cannot belong to multiple organizations.',
                                  ),
                                  backgroundColor: Colors.red,
                                ),
                              );
                              return;
                            }
                            setState(() {
                              _selectedSuggestion = s;
                              _userSearchController.text = s.userName;
                              _userSuggestions = [];
                            });
                          },
                        );
                      },
                    ),
                  ),
              ],

              const SizedBox(height: 24),

              // 3. Assign Departments Section Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: const [
                      Text(
                        'FIXED SYSTEM DEPARTMENT',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: Colors.black,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Text(
                        ' *',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFFEF4444),
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: _selectedDepartmentId != null
                          ? const Color(0xFF064E3B)
                          : Colors.black,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      _selectedDepartmentId != null ? '1 Selected' : 'Required',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // 4. Search Departments Input
              Container(
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFF1F5F9)),
                ),
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  decoration: const InputDecoration(
                    hintText: 'Search departments...',
                    hintStyle: TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                    ),
                    prefixIcon: Icon(
                      Icons.search,
                      size: 18,
                      color: Color(0xFF94A3B8),
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 12),
                  ),
                  onChanged: (val) {
                    setState(() => _searchQuery = val.trim());
                  },
                ),
              ),

              const SizedBox(height: 14),

              // 5. Department Cards List
              if (allDepartments.isEmpty)
                Container(
                  padding: const EdgeInsets.all(24),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: const Text(
                    'No departments created yet. Create a department first.',
                    style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                  ),
                )
              else if (filteredDepartments.isEmpty)
                Container(
                  padding: const EdgeInsets.all(20),
                  alignment: Alignment.center,
                  child: Text(
                    'No departments matching "$_searchQuery"',
                    style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                  ),
                )
              else
                ...filteredDepartments.map((dept) {
                  final isSelected =
                      _selectedDepartmentId == dept.departmentId;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFFF0FDF4)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFF064E3B)
                            : const Color(0xFFE2E8F0),
                        width: isSelected ? 1.5 : 1.0,
                      ),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () {
                          setState(() {
                            _selectedDepartmentId = dept.departmentId;
                          });
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      dept.departmentName,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                        color: isSelected
                                            ? const Color(0xFF064E3B)
                                            : Colors.black,
                                      ),
                                    ),
                                    if (dept.description.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        dept.description,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              // Radio-style indicator
                              Container(
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? const Color(0xFF064E3B)
                                      : Colors.white,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isSelected
                                        ? const Color(0xFF064E3B)
                                        : const Color(0xFFCBD5E1),
                                    width: 1.5,
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: isSelected
                                    ? const Icon(
                                        Icons.check,
                                        size: 14,
                                        color: Colors.white,
                                      )
                                    : null,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),

              const SizedBox(height: 24),

              // 6. Action Button: Save Changes
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _isSubmitting ? null : _submit,
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          isEditing ? 'Reassign Department' : 'Add Staff Member',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 10),

              // 7. Cancel Button
              Center(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // 8. Footer
              const Center(
                child: Text(
                  'DEVELOPED BY BIGBURRY HYPERSYSTEMS LLP',
                  style: TextStyle(
                    fontSize: 10,
                    color: Color(0xFF94A3B8),
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    ),
  ),
);
  }
}

