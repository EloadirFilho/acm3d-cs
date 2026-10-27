# encoding: UTF-8
# Salva um modelo vazio no formato desta versão do SketchUp (usado por run_tests.rb).
# Abrir um .skp evita a tela de boas-vindas, que impede o -RubyStartup de rodar.
UI.start_timer(2, false) do
  m = Sketchup.active_model
  m.entities.clear!
  m.save(ENV['CS_BASE_SKP'])
  Sketchup.quit
end
