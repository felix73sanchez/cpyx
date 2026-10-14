# Autocompletado de cpyx para fish
complete -c cpyx -s n -l dry-run -d 'Simulación: no copia nada'
complete -c cpyx -s d -l delete -d 'Borrar en destino lo que no exista en origen'
complete -c cpyx -s y -l yes -d 'No pedir confirmación'
complete -c cpyx -s x -l exclude -r -d 'Excluir patrón'
complete -c cpyx -s l -l log -r -F -d 'Guardar el log en ARCHIVO'
complete -c cpyx -s L -l no-log -d 'No guardar log'
complete -c cpyx -s V -l version -d 'Mostrar la versión'
complete -c cpyx -s h -l help -d 'Mostrar la ayuda'
