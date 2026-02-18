#!/bin/bash
 exec 3>&1 4>&2
 trap 'exec 2>&4 1>&3' 0 1 2 3

# Everything below will go to the file 'log':

target_file="exercises.c"
testcode="test.c"

git config --global user.email "you@example.com"
git config --global user.name "Your Name"

#Verifica si se realizaron cambios 
CHANGED=$(git diff --ignore-space-at-eol -b -w --ignore-blank-lines $target_file)

#Si hubieron cambios se actualiza el log
if [ -n "$CHANGED" ] || [ ! -f "a.out" ]; then
  git checkout -- $testcode log &> /dev/null
  #exec 1>>log 2>&1

  echo "$(date): " >> log
  git diff --stat --ignore-space-at-eol -b -w --ignore-blank-lines $target_file >> log

  if ! rm -f a.out 2>/dev/null; then
      echo "No se pudo eliminar 'a.out'. Por favor elimínalo manualmente." >&3
      exit 1
  fi
  echo "Eliminando 'a.out'..." >&3

  #Compilation
  echo "Compilando: gcc -g $testcode -Wall -Werror -o a.out" >&3
  gcc -g $testcode -Wall -Werror -o a.out 2>gcc_err.log

  if [ $? -eq 0 ]; then
      echo " tests: " $(($(./a.out | grep -c 'OK')))\|$(($(./a.out | grep -c 'FAILED'))) >> log
      ./a.out | tail -n1 >> log
      git rev-parse --short HEAD >> log
      git add $target_file log &> /dev/null 
      git commit -m 'new try' &> /dev/null 
  else
      echo "Complación con errores :c" >&3
      echo "Compilation failed" >> log
      cat gcc_err.log >&3   # muestra los errores reales al usuario
      cat gcc_err.log >> log
      git rev-parse --short HEAD >> log
      git add $target_file log &> /dev/null 
      git commit -m 'new try' &> /dev/null 
      exit 1
  fi


fi

#Retroalimentation

if ./a.out &> /dev/null ; then
  echo "Ejecutando: ./a.out" >&3
  
  ./a.out >&3

  echo "Quieres actualizar tu avance en el servidor? (s|n): " >&3
  read response

  if [ "$response" == "s" ]; then

    # Obtener URL de origin
    REMOTE_URL=$(git remote get-url origin)

    if [ -z "$REMOTE_URL" ]; then
      echo "No se encontró el remote 'origin'."
      exit 1
    fi

    # Extraer usuario desde la URL (ej: rilianx)
    USERNAME=$(echo "$REMOTE_URL" | sed -E 's#https://github.com/([^/]+)/.*#\1#')

    if [ -z "$USERNAME" ]; then
      echo "No se pudo extraer el usuario desde la URL."
      exit 1
    fi

    echo "Usuario detectado: $USERNAME"

    echo "--------------------------------------------"
    echo "Autenticación requerida (GitHub PAT)"
    echo ""
    echo "¿No tienes token?"
    echo "Genera uno siguiendo esta guía:"
    echo "https://chartreuse-goal-d5c.notion.site/Como-genero-un-token-de-acceso-github-30bd965dc59e805b97c5dfa3aa6276d1"
    echo "--------------------------------------------"
    echo ""
    read -s -p "Token: " TOKEN
    echo ""

    if [ -z "$TOKEN" ]; then
      echo "Token vacío. Abortando."
      exit 1
    fi

    # Construir URL temporal con token
    TEMP_URL=$(echo "$REMOTE_URL" | sed "s#https://#https://$USERNAME:$TOKEN@#")
    
    git pull >&3
    git push "$TEMP_URL" >&3
  fi
  

else
  echo "Ejecución con errores =O" >&3

  gdb -silent -ex='set disable-randomization off' -ex='set confirm off' \
      -ex='set logging file '"tmpout" -ex='run' -ex='bt' -ex=quit a.out >&3

  if grep -q "total_score" "tmpout"; then
       echo; echo "Debugger no encontró errores, pero el programa falló:" >&3
      ./a.out >&3
  else
      echo;echo "Programa falló" >&3
      
  fi 

fi
