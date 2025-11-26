class EnvConfig {
  final String supabaseUrl = 'https://fhiphyejlgjgqeygamlw.supabase.co';
  final String supabaseAnonKey = 
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZoaXBoeWVqbGdqZ3FleWdhbWx3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjQwMDQzNDUsImV4cCI6MjA3OTU4MDM0NX0.xbIIJ7PImXK-yyBX05syvai9qNzoSEzGV0Gqz6UT3Y4';

  EnvConfig() {
    _validateConfig();
  }

  void _validateConfig() {
    if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
      throw Exception('❌ Configuración de Supabase incompleta');
    }
    
    if (!supabaseUrl.startsWith('https://')) {
      throw Exception('❌ URL de Supabase inválida');
    }
    
    print('✅ Configuración de entorno validada');
  }
}