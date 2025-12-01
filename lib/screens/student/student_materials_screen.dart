import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StudentMaterialsScreen extends StatefulWidget {
  const StudentMaterialsScreen({super.key});

  @override
  State<StudentMaterialsScreen> createState() => _StudentMaterialsScreenState();
}

class _StudentMaterialsScreenState extends State<StudentMaterialsScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _materials = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMaterials();
  }

  Future<void> _loadMaterials() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final response = await _supabase
          .from('materials')
          .select('*')
          .order('created_at', ascending: false);

      setState(() {
        _materials = List<Map<String, dynamic>>.from(response);
        _filtered = _materials;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _searchMaterial(String query) {
    setState(() {
      _filtered = _materials.where((m) {
        final title = m['title']?.toLowerCase() ?? '';
        final type = m['file_type']?.toLowerCase() ?? '';
        return title.contains(query.toLowerCase()) ||
               type.contains(query.toLowerCase());
      }).toList();
    });
  }

  IconData _getFileIcon(String fileType) {
    switch (fileType) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'document':
        return Icons.description;
      case 'image':
        return Icons.image;
      case 'video':
        return Icons.video_library;
      case 'link':
        return Icons.link;
      default:
        return Icons.insert_drive_file;
    }
  }

  Color _getFileColor(String fileType) {
    switch (fileType) {
      case 'pdf':
        return Colors.red;
      case 'document':
        return Colors.blue;
      case 'image':
        return Colors.green;
      case 'video':
        return Colors.purple;
      case 'link':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Materiales del Curso')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Buscador
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: TextField(
                    onChanged: _searchMaterial,
                    decoration: const InputDecoration(
                      labelText: 'Buscar material...',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),

                // Lista de materiales
                Expanded(
                  child: _filtered.isEmpty
                      ? const Center(
                          child: Text('No hay materiales disponibles'),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filtered.length,
                          itemBuilder: (context, index) {
                            final material = _filtered[index];
                            return Card(
                              child: ListTile(
                                leading: Icon(
                                  _getFileIcon(material['file_type']),
                                  color: _getFileColor(material['file_type']),
                                ),
                                title: Text(material['title'] ?? 'Sin título'),
                                subtitle: Text(material['file_type'] ?? ''),
                                onTap: () {
                                  // Aquí puedes abrir el archivo o enlace
                                },
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
