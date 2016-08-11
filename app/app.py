# -*- coding: utf-8 -*-
"""
    Autman
    ~~~~~~
    Sistema de automanção de manobras.
    :copyright: (c) 2016 by Sergio Dias.
    :license: BSD, see LICENSE for more details.
"""
import os
import sys
from sqlite3 import dbapi2 as sqlite3
from flask import Flask, request, session, g, jsonify, redirect, url_for, abort, \
     render_template, flash
from time import gmtime, strftime
import paramiko
import time


# create our little application :)
app = Flask(__name__)

# Load default config and override config from an environment variable
app.config.update(dict(
    #DATABASE=os.path.join(app.root_path, 'autman.db'),
    DEBUG=True,
    SECRET_KEY='bZJc2sWbQLKos6GkHn/VB9oXwQt8S0R0kRvJ5/xJ89E=',
    USERNAME='admin',
    PASSWORD='default',
    IP_SAGE='192.168.0.18',
    USER_SAGE='sage',
    PASS_SAGE='sage'
))
app.config.from_envvar('FLASKR_SETTINGS', silent=True)

#Conecta ao banco

conn = sqlite3.connect('autman.db')

comandos = conn.execute('select c.codigo as equipamento, c.tipo as tipo, a.comando as comando, d.codigo as unidade, b.descricao AS Acao from roteiro_comando a inner join roteiro_manobra_item b on b.id=a.id_roteiro_manobra_item inner join equipamento c on c.id=a.id_equipamento inner join unidade d on d.id=b.id_unidade')

if comandos:

   ssh = paramiko.SSHClient()
   ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
   ssh.connect(app.config['IP_SAGE'], username=app.config['USER_SAGE'], password=app.config['PASS_SAGE'])

   for item_comando in comandos:

       ssh_stdin, ssh_stdout, ssh_stderr = ssh.exec_command("sage_ctrl %s:%s:%d %d" % (item_comando[3], item_comando[0], item_comando[1], item_comando[2])) 
       print "sage_ctrl %s:%s:%d %d" % (item_comando[3], item_comando[0], item_comando[1], item_comando[2]), "%s" % (item_comando[4])
       time.sleep(4)
    #ssh_stdin, ssh_stdout, ssh_stderr = ssh.exec_command("sage_ctrl %s:%s:%d %d" % (item_comando['unidade'], item_comando['equipamento'],item_comando['tipo'], item_comando['comando'])) 
    #ssh_stdin, ssh_stdout, ssh_stderr = ssh.exec_command('sage_ctrl JCD:14C1:52 0')
#ssh_stdin, ssh_stdout, ssh_stderr = ssh.exec_command('ls')
    #for line in ssh_stdout:
    #	print '... ' + line.strip('\n')
   ssh.close()

