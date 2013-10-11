# Django Aliases

schemamigration() {
    # Django South schemamigration
    ./manage.py schemamigration $@ --auto
}

migrate() {
    # Django South migrate
    ./manage.py migrate $@
}

alias dbshell="python manage.py dbshell"
alias runserver="python manage.py runserver 0.0.0.0:8000"
alias shell="python manage.py shell"
alias startapp="python manage.py startapp"
alias syncdb="python manage.py syncdb"
