#!/bin/bash

for i in {6..20}
do
  user="student$i"

  # 로그인 중인지 확인
  if who | grep -q "$user"; then
    echo "$user is currently logged in → skip"
  else
    sudo userdel -r "$user"
    echo "$user deleted"
  fi
done
