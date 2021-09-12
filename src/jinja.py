
import jinja2
from jinja2 import Template
import yaml

with open('win10efi.desktop.j2') as file_:
    template = Template(file_.read())

data = yaml.load( open('user.yaml'))

templateout = template.render(data)

print(templateout)
