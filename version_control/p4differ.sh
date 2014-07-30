for (( i = 1; i <= "${#}"; i += 3 )); do
  before="${i}"
  after="$((before + 1))"
  diff --unified "${!before}" "${!after}"
done
