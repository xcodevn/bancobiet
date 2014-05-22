express = require 'express'

console.log "Setting up database"
sqlite3 = require 'sqlite3'
db = new sqlite3.Database 'data.db'

try
  db.serialize =>
      db.run 'CREATE TABLE IF NOT EXISTS tb_post (id INTEGER PRIMARY KEY AUTOINCREMENT, date DATETIME, text TEXT, source TEXT, status TEXT)'
catch er
  console.log "Error"

app = express()
logger = require 'morgan'
bodyParser = require 'body-parser'

errorHandler = require 'errorhandler'

app.use express.static __dirname + '/public'

cookieParser = require 'cookie-parser'
session      = require 'express-session'
app.use cookieParser()
app.use session({ secret: 'thong tin bi mat khong ai co the biet duoc', name: 'sid'})

app.use logger()
app.use errorHandler({ dumpExceptions: false, showStack: false })
app.use bodyParser()



app.set 'views', __dirname + '/views'
app.set 'view engine', 'jade'

requireAdmin = (req, res, next) ->
  if req.session.admin?
    next()
  else
    res.render 'error'

app.get '/ping', (req, res) ->
  res.send 'pong'

app.get '/boaimabietduoc', (req, res) ->
  req.session.admin = true
  res.redirect '/admin'

app.get '/more', (req, res) ->
  db.get 'SELECT * FROM tb_post WHERE status = "ACCEPTED" ORDER BY RANDOM() LIMIT 1', (err, row) ->
    if err?
      res.render 'error'
    else
      res.render 'index', {row: row}

app.get '/new', (req, res) ->
  res.render 'new', {}

app.post '/new', [], (req, res) ->
  usertext = ""
  if req.body.usertext?
    usertext = req.body.usertext
  source = ""
  if req.body.source?
    source = req.body.source

  if usertext.length > 0
    db.run "INSERT INTO tb_post (date, text, source, status) VALUES (datetime(), ?, ?,?)", usertext, source, "NEWPOST", (err) ->
      if err?
        console.log err
        res.render 'error'
    res.render 'new_ok',{}
  else
    res.render 'new', {}

app.get '/', (req, res) ->
  db.get 'SELECT * FROM tb_post WHERE status = "ACCEPTED" ORDER BY RANDOM() LIMIT 1', (err, row) ->
    if err?
      res.render 'error'
    else
      res.render 'index', {row: row}

app.get '/error', (req, res) ->
  res.render 'error', {}

app.get '/admin', requireAdmin, (req, res) ->
  db.all "SELECT * FROM tb_post WHERE status = ? ORDER BY date desc", "NEWPOST", (err, rows) ->
    if err?
      console.log err
      res.render 'error', {}
    else
      res.render 'admin', {"rows": rows}

app.param (name, fn) ->
  if fn instanceof RegExp
    (req, res, next, val) ->
      captures = undefined
      if captures = fn.exec(String(val))
        req.params[name] = captures
        next()
      else
        next "route"
      return

app.param('id', /^\d+$/)

app.get '/accept/:id', requireAdmin, (req, res) ->
  db.run 'UPDATE tb_post SET status = ? WHERE id = ?', "ACCEPTED", req.params.id[0], (err) ->
    if err?
      console.log err
      res.render 'error'
  res.redirect '/admin'

app.get '/post/:id', (req, res) ->
  db.get "SELECT * FROM tb_post WHERE status = ? AND id = ?", "ACCEPTED", req.params.id[0], (err, row) ->
    if err? or not row?
      res.render 'error'
    else
      res.render 'index', {row: row}

app.get '/delete/:id', requireAdmin, (req, res) ->
  db.run 'DELETE FROM tb_post WHERE id = ?', req.params.id[0], (err) ->
    if err?
      console.log err
      res.render 'error'
  res.redirect '/admin'

app.get '/edit/:id', requireAdmin, (req, res) ->
  db.get 'SELECT  id, text, source FROM tb_post WHERE id = ?', req.params.id[0], (err, row) ->
    if err?
      console.log err
      res.render 'error'
    else
      res.render 'edit', {row: row}

app.post '/edit/:id', requireAdmin, (req, res) ->
  db.run 'UPDATE tb_post SET text = ?, source = ? WHERE id = ?', req.body.usertext, req.body.source, req.params.id[0], (err) ->
    if err?
      console.log err
      res.render 'error'
    else
      res.redirect '/admin'

app.get '*', (req, res) ->
  res.render 'error', {}

app.post '*', (req, res) ->
  res.render 'error', {}

server = app.listen 3000, ->
  console.log "Server is listening on port #{server.address().port}"

