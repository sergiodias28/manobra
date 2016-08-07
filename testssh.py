# -*- coding: utf-8 -*-
"""
    Autman
    ~~~~~~
    Sistema de automanção de manobras.
    :copyright: (c) 2015 by Sergio Dias.
    :license: BSD, see LICENSE for more details.
"""
import os
import sys
from sqlite3 import dbapi2 as sqlite3
from flask import Flask, request, session, g, jsonify, redirect, url_for, abort, \
     render_template, flash
from time import gmtime, strftime
import paramiko

# create our little application :)
app = Flask(__name__)

# Load default config and override config from an environment variable
app.config.update(dict(
    #DATABASE=os.path.join(app.root_path, 'autman.db'),
    DEBUG=True,
    SECRET_KEY='bZJc2sWbQLKos6GkHn/VB9oXwQt8S0R0kRvJ5/xJ89E=',
    USERNAME='admin',
    PASSWORD='default',
    IP_SAGE='192.168.0.14',
    USER_SAGE='sage',
    PASS_SAGE='sage'
))
app.config.from_envvar('FLASKR_SETTINGS', silent=True)

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect(app.config['IP_SAGE'], username=app.config['USER_SAGE'], password=app.config['PASS_SAGE'])
#ssh_stdin, ssh_stdout, ssh_stderr = ssh.exec_command('sage_ctrl JCD:14C1:52 0')
ssh_stdin, ssh_stdout, ssh_stderr = ssh.exec_command('ls')
for line in ssh_stdout:
    	print '... ' + line.strip('\n')
ssh.close()


