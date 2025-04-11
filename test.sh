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

  echo "Quiere actualizar su avance en el servidor? (s|n): " >&3
  read response

  if [ "$response" == "s" ]; then
    git pull >&3
    git push >&3
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
