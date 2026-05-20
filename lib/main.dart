import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';

// ─────────────────────────────────────────────────────────────────
//  ENTRY POINT
// ─────────────────────────────────────────────────────────────────
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Hive.openBox('appBox');
  runApp(MaterialApp(
    theme: AppTheme.theme,
    debugShowCheckedModeBanner: false,
    home: const SectionDetailScreen(nsKey: '.', sectionName: '.'),
  ));
}

// ─────────────────────────────────────────────────────────────────
//  THEME
// ─────────────────────────────────────────────────────────────────
class AppTheme {
  static const primary = Color(0xFF1565C0);
  static const accent = Color(0xFF42A5F5);
  static const bg = Color(0xFFF0F4FF);
  static const cardBg = Colors.white;
  static const green = Color(0xFF2E7D32);
  static const orange = Color(0xFFE65100);
  static const red = Color(0xFFC62828);

  static ThemeData get theme => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: primary),
        scaffoldBackgroundColor: bg,
        appBarTheme: const AppBarTheme(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primary,
            foregroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding:
                const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border:
              OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────
//  GLOBAL BOX HELPERS
// ─────────────────────────────────────────────────────────────────
Box get _box => Hive.box('appBox');


// ── Attendance helpers ──────────────────────────────────────────
void _saveAttendance(
    String date, String lecture, List<Student> students) {
  _box.put(
      'att_${date}_lec$lecture', students.map((s) => s.toMap()).toList());
}

List<Student>? _loadAttendance(String date, String lecture) {
  final raw = _box.get('att_${date}_lec$lecture');
  if (raw == null) return null;
  return (raw as List).map((e) => Student.fromMap(Map.from(e))).toList();
}

List<String> _lecturesForDate(String date) {
  final List<String> found = [];
  for (var k in _box.keys) {
    final s = k.toString();
    if (s.startsWith('att_${date}_lec')) {
      found.add(s.replaceFirst('att_${date}_lec', ''));
    }
  }
  found.sort();
  return found;
}

// ── Student list helpers ─────────────────────────────────────────
List<Student> _loadStudentList(String key) {
  final raw = _box.get(key);
  if (raw == null) return [];
  // Always reset status to absent — statuses belong in attendance records,
  // not the master student roster. This prevents lecture 1 statuses
  // from leaking into lecture 2 or any fresh session.
  return (raw as List)
      .map((e) {
        final m = Map<String, dynamic>.from(e as Map);
        return Student(m['rollNo'] as String, m['name'] as String,
            status: AttendanceStatus.absent);
      })
      .toList()
    ..sort((a, b) => a.rollNo.compareTo(b.rollNo));
}

void _saveStudentList(String key, List<Student> students) {
  _box.put(key, students.map((s) => s.toMap()).toList());
}

// ── Section helpers ──────────────────────────────────────────────


// ── Student list key per section ────────────────────────────────
String _sectionStudentKey(String nsKey, String sectionName) =>
    '${nsKey}_sect_$sectionName';

// ─────────────────────────────────────────────────────────────────
//  MODELS
// ─────────────────────────────────────────────────────────────────
enum AttendanceStatus { present, absent, pod }

class Student {
  final String rollNo;
  final String name;
  AttendanceStatus status;

  Student(this.rollNo, this.name,
      {this.status = AttendanceStatus.absent});

  Map<String, dynamic> toMap() =>
      {'rollNo': rollNo, 'name': name, 'status': status.index};

  static Student fromMap(Map map) => Student(
        map['rollNo'],
        map['name'],
        status: AttendanceStatus.values[map['status']],
      );
}

// ─────────────────────────────────────────────────────────────────
//  SECTION DETAIL SCREEN  (students + take attendance)
// ─────────────────────────────────────────────────────────────────
class SectionDetailScreen extends StatelessWidget {
  final String nsKey;
  final String sectionName;
  const SectionDetailScreen(
      {super.key, required this.nsKey, required this.sectionName});

  @override
  Widget build(BuildContext context) {
    final studentKey = _sectionStudentKey(nsKey, sectionName);
    return Scaffold(
      appBar: AppBar(title: Text("Section: $sectionName")),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _card(
            context,
            icon: Icons.people,
            title: "Manage Students",
            subtitle: "Add or remove students in this section",
            color: AppTheme.primary,
            onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => ManageStudentsScreen(
                        listKey: studentKey,
                        title: '$sectionName · Students'))),
          ),
          const SizedBox(height: 16),
          _card(
            context,
            icon: Icons.fact_check,
            title: "Take Attendance",
            subtitle: "Mark attendance for a lecture in this section",
            color: AppTheme.green,
            onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                        DateLectureScreen(studentListKey: studentKey))),
          ),
        ],
      ),
    );
  }

  Widget _card(BuildContext context,
      {required IconData icon,
      required String title,
      required String subtitle,
      required Color color,
      required VoidCallback onTap}) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: color.withValues(alpha: 0.15),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(subtitle,
                        style: TextStyle(
                            fontSize: 13, color: Colors.grey.shade600)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  MANAGE STUDENTS SCREEN  (Add / Delete / CSV import)
// ─────────────────────────────────────────────────────────────────
class ManageStudentsScreen extends StatefulWidget {
  final String listKey;
  final String title;
  const ManageStudentsScreen(
      {super.key, required this.listKey, required this.title});

  @override
  State<ManageStudentsScreen> createState() => _ManageStudentsScreenState();
}

class _ManageStudentsScreenState extends State<ManageStudentsScreen> {
  late List<Student> _students;
  bool _deleteMode = false;
  final Set<Student> _selected = {};

  @override
  void initState() {
    super.initState();
    _students = _loadStudentList(widget.listKey);
  }

  void _save() {
    _saveStudentList(widget.listKey, _students);
    setState(() {});
  }

  // ── Add single student ───────────────────────────────────────
  void _showAddDialog() {
    final rollCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Add Student"),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: rollCtrl,
              decoration: const InputDecoration(
                  labelText: "Roll Number",
                  prefixIcon: Icon(Icons.confirmation_number)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nameCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                  labelText: "Student Name",
                  prefixIcon: Icon(Icons.person)),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              final roll = rollCtrl.text.trim();
              final name = nameCtrl.text.trim().toUpperCase();
              if (roll.isNotEmpty && name.isNotEmpty) {
                if (_students.any((s) => s.rollNo == roll)) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text("Roll number already exists")));
                  return;
                }
                setState(() {
                  _students.add(Student(roll, name));
                  _students.sort((a, b) => a.rollNo.compareTo(b.rollNo));
                });
                _save();
                Navigator.pop(context);
              }
            },
            child: const Text("Add"),
          ),
        ],
      ),
    );
  }

  // ── CSV / Excel-like paste import ────────────────────────────
  void _showCsvImportDialog() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Paste CSV Data"),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: const Text(
                "Format: ROLL,NAME (one per line)\n"
                "Example:\n  0537CS241061,Kunal Soni",
                style: TextStyle(fontSize: 13),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              maxLines: 10,
              decoration: const InputDecoration(
                hintText: "Paste your CSV data here...",
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              final lines = ctrl.text
                  .trim()
                  .split('\n')
                  .where((l) => l.trim().contains(','))
                  .toList();
              int added = 0, skipped = 0;
              for (var line in lines) {
                final parts = line.split(',');
                if (parts.length >= 2) {
                  final roll = parts[0].trim();
                  final name =
                      parts.sublist(1).join(',').trim().toUpperCase();
                  if (roll.isNotEmpty && name.isNotEmpty) {
                    if (_students.any((s) => s.rollNo == roll)) {
                      skipped++;
                    } else {
                      _students.add(Student(roll, name));
                      added++;
                    }
                  }
                }
              }
              _students.sort((a, b) => a.rollNo.compareTo(b.rollNo));
              _save();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(
                      "$added students added${skipped > 0 ? ', $skipped duplicates skipped' : ''}")));
            },
            child: const Text("Import"),
          ),
        ],
      ),
    );
  }

  void _confirmDelete() {
    if (_selected.isEmpty) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Delete Students"),
        content: Text("Delete ${_selected.length} selected student(s)?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel")),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: AppTheme.red),
            onPressed: () {
              setState(() {
                _students.removeWhere((s) => _selected.contains(s));
                _selected.clear();
                _deleteMode = false;
              });
              _save();
              Navigator.pop(context);
            },
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }

  // ── Edit student name ────────────────────────────────────────
  void _showEditDialog(Student s) {
    final nameCtrl = TextEditingController(text: s.name);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Edit Student"),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        content: TextField(
          controller: nameCtrl,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
              labelText: "Student Name",
              prefixIcon: Icon(Icons.person)),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              final newName = nameCtrl.text.trim().toUpperCase();
              if (newName.isNotEmpty) {
                setState(() {
                  final idx = _students.indexOf(s);
                  _students[idx] =
                      Student(s.rollNo, newName, status: s.status);
                });
                _save();
                Navigator.pop(context);
              }
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
              icon: const Icon(Icons.upload_file),
              tooltip: "Import CSV",
              onPressed: _showCsvImportDialog),
          IconButton(
              icon: const Icon(Icons.person_add),
              tooltip: "Add Student",
              onPressed: _showAddDialog),
          if (!_deleteMode)
            IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: "Delete Mode",
                onPressed: () => setState(() => _deleteMode = true)),
          if (_deleteMode)
            IconButton(
                icon: const Icon(Icons.check),
                tooltip: "Confirm Delete",
                onPressed: _confirmDelete),
          if (_deleteMode)
            IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => setState(() {
                      _deleteMode = false;
                      _selected.clear();
                    })),
        ],
      ),
      body: _students.isEmpty
          ? const Center(
              child: Text("No students yet.\nAdd manually or import CSV.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey)))
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Text("Total: ${_students.length} students",
                          style: TextStyle(
                              color: Colors.grey.shade700, fontSize: 13)),
                      if (_deleteMode)
                        Padding(
                          padding: const EdgeInsets.only(left: 12),
                          child: Text(
                            "${_selected.length} selected",
                            style: const TextStyle(
                                color: AppTheme.red, fontSize: 13),
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10),
                    itemCount: _students.length,
                    itemBuilder: (ctx, i) {
                      final s = _students[i];
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 5),
                        child: ListTile(
                          leading: _deleteMode
                              ? Checkbox(
                                  value: _selected.contains(s),
                                  onChanged: (v) => setState(() => v!
                                      ? _selected.add(s)
                                      : _selected.remove(s)),
                                )
                              : CircleAvatar(
                                  backgroundColor:
                                      AppTheme.accent.withValues(alpha: 0.2),
                                  child: Text(
                                    s.rollNo.length >= 3
                                        ? s.rollNo.substring(
                                            s.rollNo.length - 3)
                                        : s.rollNo,
                                    style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.primary),
                                  ),
                                ),
                          title: Text(s.name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w500)),
                          subtitle: Text("Roll: ${s.rollNo}"),
                          trailing: !_deleteMode
                              ? IconButton(
                                  icon: const Icon(Icons.edit_outlined,
                                      size: 18, color: Colors.grey),
                                  onPressed: () => _showEditDialog(s),
                                )
                              : null,
                          onLongPress: !_deleteMode
                              ? () => setState(() {
                                    _deleteMode = true;
                                    _selected.add(s);
                                  })
                              : null,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  DATE + LECTURE SELECTION SCREEN
// ─────────────────────────────────────────────────────────────────
class DateLectureScreen extends StatefulWidget {
  final String studentListKey;
  const DateLectureScreen({super.key, required this.studentListKey});

  @override
  State<DateLectureScreen> createState() => _DateLectureScreenState();
}

class _DateLectureScreenState extends State<DateLectureScreen> {
  late DateTime _selectedDate;
  String _selectedLecture = "1";
  bool _isPastDate = false;
  List<String> _pastLectures = [];

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _checkPastDate();
  }

  void _checkPastDate() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final sel = DateTime(
        _selectedDate.year, _selectedDate.month, _selectedDate.day);
    _isPastDate = sel.isBefore(today);
    if (_isPastDate) {
      final dateStr = DateFormat("dd MMM yyyy").format(_selectedDate);
      _pastLectures = _lecturesForDate(dateStr);
    } else {
      _pastLectures = [];
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _checkPastDate();
        _selectedLecture =
            _pastLectures.isNotEmpty ? _pastLectures.first : "1";
      });
    }
  }

  void _proceed() {
    final dateStr = DateFormat("dd MMM yyyy").format(_selectedDate);
    if (_isPastDate) {
      final saved = _loadAttendance(dateStr, _selectedLecture);
      if (saved == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("No attendance found for this date & lecture")));
        return;
      }
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: Text("Lecture $_selectedLecture"),
          content: Text("$dateStr\nWhat would you like to do?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.visibility),
              label: const Text("View Report"),
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(
                    builder: (_) => ReportScreen(
                        students: saved,
                        lecture: _selectedLecture,
                        date: dateStr)));
              },
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.orange),
              icon: const Icon(Icons.edit),
              label: const Text("Update"),
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(
                    builder: (_) => AttendanceScreen(
                        lecture: _selectedLecture,
                        date: dateStr,
                        students: saved,
                        isUpdate: true)));
              },
            ),
          ],
        ),
      );
    } else {
      final existing = _loadAttendance(dateStr, _selectedLecture);
      if (existing != null) {
        Navigator.push(context, MaterialPageRoute(
            builder: (_) => AttendanceScreen(
                lecture: _selectedLecture,
                date: dateStr,
                students: existing)));
        return;
      }
      List<Student> students = _loadStudentList(widget.studentListKey);
      if (students.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("No students found. Please add students first.")));
        return;
      }
      students = students
          .map((s) => Student(s.rollNo, s.name, status: AttendanceStatus.absent))
          .toList();
      Navigator.push(context, MaterialPageRoute(
          builder: (_) => AttendanceScreen(
              lecture: _selectedLecture,
              date: dateStr,
              students: students)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat("dd MMM yyyy").format(_selectedDate);
    return Scaffold(
      appBar: AppBar(title: const Text("Lecture Details")),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  InkWell(
                    onTap: _pickDate,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          vertical: 14, horizontal: 14),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today,
                              color: AppTheme.primary),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(dateStr,
                                style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500)),
                          ),
                          const Icon(Icons.edit,
                              size: 18, color: Colors.grey),
                        ],
                      ),
                    ),
                  ),
                  if (_isPastDate && _pastLectures.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                          "No attendance recorded for this date.",
                          style: TextStyle(
                              color: Colors.orange.shade700)),
                    ),
                  const SizedBox(height: 20),
                  // ignore: deprecated_member_use
                  DropdownButtonFormField<String>(
                    initialValue: _selectedLecture,
                    decoration: InputDecoration(
                      labelText: "Lecture",
                      prefixIcon: const Icon(Icons.class_),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    items: (_isPastDate && _pastLectures.isNotEmpty
                            ? _pastLectures
                            : ["1", "2", "3", "4", "5", "6"])
                        .map((e) => DropdownMenuItem(
                            value: e, child: Text("Lecture $e")))
                        .toList(),
                    onChanged: (v) =>
                        setState(() => _selectedLecture = v!),
                  ),
                  if (_isPastDate && _pastLectures.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border:
                              Border.all(color: Colors.amber.shade300),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline,
                                color: Colors.amber, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                "Past date: showing existing attendance records.",
                                style: TextStyle(
                                    color: Colors.amber.shade900,
                                    fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    child: Builder(builder: (context) {
                      final dateStr2 = DateFormat("dd MMM yyyy").format(_selectedDate);
                      final hasExisting = !_isPastDate && _loadAttendance(dateStr2, _selectedLecture) != null;
                      return ElevatedButton.icon(
                        icon: Icon(_isPastDate
                            ? Icons.visibility
                            : hasExisting ? Icons.play_circle_filled : Icons.play_arrow),
                        label: Text(
                          _isPastDate
                              ? "VIEW / UPDATE"
                              : hasExisting ? "RESUME ATTENDANCE" : "START ATTENDANCE",
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                        style: hasExisting && !_isPastDate
                            ? ElevatedButton.styleFrom(backgroundColor: AppTheme.green)
                            : null,
                        onPressed: _proceed,
                      );
                    }),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  ATTENDANCE SCREEN
// ─────────────────────────────────────────────────────────────────
class AttendanceScreen extends StatefulWidget {
  final String lecture;
  final String date;
  final List<Student> students;
  final bool isUpdate;

  const AttendanceScreen({
    super.key,
    required this.lecture,
    required this.date,
    required this.students,
    this.isUpdate = false,
  });

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  late List<Student> students;
  bool deleteMode = false;
  final Set<Student> selectedStudents = {};

  int get _presentCount =>
      students.where((s) => s.status == AttendanceStatus.present).length;
  int get _podCount =>
      students.where((s) => s.status == AttendanceStatus.pod).length;
  int get _absentCount =>
      students.where((s) => s.status == AttendanceStatus.absent).length;

  @override
  void initState() {
    super.initState();
    students = widget.students;
  }

  void _showAddStudentDialog() {
    final rollCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Add Student"),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: rollCtrl,
                decoration: const InputDecoration(
                    labelText: "Roll Number",
                    prefixIcon: Icon(Icons.confirmation_number))),
            const SizedBox(height: 12),
            TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                    labelText: "Student Name",
                    prefixIcon: Icon(Icons.person))),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              if (rollCtrl.text.isNotEmpty && nameCtrl.text.isNotEmpty) {
                setState(() {
                  students.add(Student(rollCtrl.text.trim(),
                      nameCtrl.text.trim().toUpperCase()));
                  students.sort((a, b) => a.rollNo.compareTo(b.rollNo));
                });
                Navigator.pop(context);
              }
            },
            child: const Text("Add"),
          ),
        ],
      ),
    );
  }

  void _confirmBulkDelete() {
    if (selectedStudents.isEmpty) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Delete Students"),
        content:
            Text("Delete ${selectedStudents.length} selected student(s)?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel")),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: AppTheme.red),
            onPressed: () {
              setState(() {
                students
                    .removeWhere((s) => selectedStudents.contains(s));
                selectedStudents.clear();
                deleteMode = false;
              });
              Navigator.pop(context);
            },
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Lecture ${widget.lecture}"),
            if (widget.isUpdate) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.orange,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text("UPDATE", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(36),
          child: Container(
            color: AppTheme.primary.withValues(alpha: 0.85),
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _summaryChip(
                    Icons.check_circle, "$_presentCount P", Colors.green),
                _summaryChip(
                    Icons.work, "$_podCount POD", Colors.orange),
                _summaryChip(
                    Icons.cancel, "$_absentCount A", Colors.red),
              ],
            ),
          ),
        ),
        actions: [
          IconButton(
              icon: const Icon(Icons.person_add),
              tooltip: "Add Student",
              onPressed: _showAddStudentDialog),
          if (!deleteMode)
            IconButton(
                icon: const Icon(Icons.delete),
                tooltip: "Delete Mode",
                onPressed: () => setState(() {
                      deleteMode = true;
                      selectedStudents.clear();
                    })),
          if (deleteMode)
            IconButton(
                icon: const Icon(Icons.check),
                onPressed: _confirmBulkDelete),
          if (deleteMode)
            IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => setState(() {
                      deleteMode = false;
                      selectedStudents.clear();
                    })),
        ],
      ),
      body: ListView.builder(
        itemCount: students.length,
        padding: const EdgeInsets.all(10),
        itemBuilder: (context, index) {
          final student = students[index];
          final shortRoll = student.rollNo.length >= 3
              ? student.rollNo.substring(student.rollNo.length - 3)
              : student.rollNo;

          Color color;
          String text;
          IconData icon;
          switch (student.status) {
            case AttendanceStatus.present:
              color = Colors.green;
              text = "P";
              icon = Icons.check_circle;
              break;
            case AttendanceStatus.pod:
              color = Colors.orange;
              text = "POD";
              icon = Icons.work;
              break;
            default:
              color = Colors.red;
              text = "A";
              icon = Icons.cancel;
          }

          return Card(
            elevation: 3,
            margin: const EdgeInsets.symmetric(vertical: 6),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  vertical: 10, horizontal: 12),
              child: Row(
                children: [
                  if (deleteMode)
                    Checkbox(
                      value: selectedStudents.contains(student),
                      onChanged: (v) => setState(() => v!
                          ? selectedStudents.add(student)
                          : selectedStudents.remove(student)),
                    ),
                  Container(
                    width: 45,
                    height: 45,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.blue.shade100,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(shortRoll,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(student.name,
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500)),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: color,
                      minimumSize: const Size(90, 40),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: Icon(icon, color: Colors.white),
                    label: Text(text,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold)),
                    onPressed: () {
                      if (deleteMode) return;
                      setState(() {
                        if (student.status == AttendanceStatus.absent) {
                          student.status = AttendanceStatus.present;
                        } else if (student.status == AttendanceStatus.present) {
                          student.status = AttendanceStatus.pod;
                        } else {
                          student.status = AttendanceStatus.absent;
                        }
                      });
                      // Auto-save instantly after every tap
                      _saveAttendance(widget.date, widget.lecture, students);
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.done),
        label: Text(widget.isUpdate ? "Save Update" : "Done"),
        backgroundColor: widget.isUpdate ? AppTheme.orange : AppTheme.green,
        onPressed: () {
          _saveAttendance(widget.date, widget.lecture, students);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(children: const [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text("Attendance saved!"),
              ]),
              backgroundColor: AppTheme.green,
              duration: const Duration(seconds: 2),
            ),
          );
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => ReportScreen(
                        students: students,
                        lecture: widget.lecture,
                        date: widget.date,
                      )));
        },
      ),
    );
  }

  Widget _summaryChip(IconData icon, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 4),
        Text(label,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.bold)),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  REPORT SCREEN
// ─────────────────────────────────────────────────────────────────
class ReportScreen extends StatelessWidget {
  final List<Student> students;
  final String lecture;
  final String date;

  const ReportScreen({
    super.key,
    required this.students,
    required this.lecture,
    required this.date,
  });

  List<Student> get _present =>
      students.where((s) => s.status == AttendanceStatus.present).toList();
  List<Student> get _pod =>
      students.where((s) => s.status == AttendanceStatus.pod).toList();
  List<Student> get _absent =>
      students.where((s) => s.status == AttendanceStatus.absent).toList();

  String _presentPodText() {
    String t = "Lecture: $lecture\n Date: $date\n\n Present:\n";
    for (var s in _present) {
      t += "${s.rollNo}  ${s.name}\n";
    }
    if (_pod.isNotEmpty) {
      t += "\nPOD:\n";
      for (var s in _pod) {
        t += "${s.rollNo}  ${s.name}\n";
      }
    }
    return t;
  }

  String _absentText() {
    String t = "Lecture: $lecture\n Date: $date\n\n❌ Absent:\n";
    for (var s in _absent) {
      t += "${s.rollNo}  ${s.name}\n";
    }
    return t;
  }

  @override
  Widget build(BuildContext context) {
    final total = students.length;
    final presentPod = _present.length + _pod.length;
    final pct = total > 0
        ? (presentPod / total * 100).toStringAsFixed(1)
        : "0";

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
          title: const Text("Attendance Report"), centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Summary card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text("Lecture $lecture",
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(date,
                        style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600)),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _statPill(
                            "Present", _present.length, Colors.green),
                        _statPill("POD", _pod.length, Colors.orange),
                        _statPill("Absent", _absent.length, Colors.red),
                        _statPill("Total", total, AppTheme.primary),
                      ],
                    ),
                    const SizedBox(height: 12),
                    LinearProgressIndicator(
                      value: total > 0 ? presentPod / total : 0,
                      backgroundColor: Colors.red.shade100,
                      color: Colors.green,
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    const SizedBox(height: 6),
                    Text("$pct% Attendance",
                        style: TextStyle(
                            color: Colors.grey.shade700, fontSize: 13)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            _sectionCard(
              title: "Present & POD",
              count: _present.length + _pod.length,
              color: Colors.green,
              children: [
                ..._present.map((s) => _studentRow(s)),
                if (_pod.isNotEmpty) ...[
                  const Divider(),
                  ..._pod.map((s) => _studentRow(s, isPod: true)),
                ],
              ],
            ),
            const SizedBox(height: 16),
            _sectionCard(
              title: "Absent",
              count: _absent.length,
              color: Colors.red,
              children: _absent.map((s) => _studentRow(s)).toList(),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Update Attendance button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.edit),
                label: const Text("Update Attendance",
                    style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.orange),
                onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => AttendanceScreen(
                            lecture: lecture,
                            date: date,
                            students: List<Student>.from(
                                students.map((s) => Student(s.rollNo, s.name, status: s.status))),
                            isUpdate: true))),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.copy, color: Colors.black),
                    label: const Text("Copy Present + POD",
                        style: TextStyle(color: Colors.black)),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white),
                    onPressed: () => Clipboard.setData(
                        ClipboardData(text: _presentPodText())),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.share, color: Colors.black),
                    label: const Text("Share",
                        style: TextStyle(color: Colors.black)),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white),
                    onPressed: () => Share.share(_presentPodText()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.copy, color: Colors.white),
                    label: const Text("Copy Absent",
                        style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.red),
                    onPressed: () => Clipboard.setData(
                        ClipboardData(text: _absentText())),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.share, color: Colors.white),
                    label: const Text("Share Absent",
                        style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.red),
                    onPressed: () => Share.share(_absentText()),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statPill(String label, int value, Color color) {
    return Column(
      children: [
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(value.toString(),
              style: TextStyle(
                  color: color,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 4),
        Text(label,
            style:
                TextStyle(fontSize: 11, color: Colors.grey.shade600)),
      ],
    );
  }

  Widget _sectionCard({
    required String title,
    required int count,
    required Color color,
    required List<Widget> children,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
                const Spacer(),
                CircleAvatar(
                  radius: 14,
                  backgroundColor: color,
                  child: Text(count.toString(),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _studentRow(Student s, {bool isPod = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          if (isPod)
            const Padding(
              padding: EdgeInsets.only(right: 6),
            ),
          Text("${s.rollNo}  ${s.name}",
              style: TextStyle(
                  fontSize: 14,
                  color: isPod ? Colors.orange : Colors.black87)),
        ],
      ),
    );
  }
} 