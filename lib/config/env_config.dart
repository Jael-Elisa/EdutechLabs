class EnvConfig {
  final String supabaseUrl = 'https://iampwosufztefxonbusb.supabase.co';
  final String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImlhbXB3b3N1Znp0ZWZ4b25idXNiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjQxODE5MzAsImV4cCI6MjA3OTc1NzkzMH0.KeFe8Db2jBuSMdqELatv56FEHfyLLqnBtGrIQEhep7E';

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
