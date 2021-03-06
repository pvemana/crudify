crudify = require '../'
should = require 'should'
express = require 'express'
request = require 'request'
require 'mocha'

db = require './fixtures/connection'
User = db.model 'User'
crud = crudify db
crud.expose 'User'

PORT = process.env.PORT or 9001

app = express()
app.use express.json()

crud.pre 'handle', (req, res, next) ->
  should.exist req
  should.exist res
  next()

crud.get('User').pre 'handle', (req, res, next) ->
  should.exist req
  should.exist res
  next()

crud.hook app
app.listen PORT

tom =
  name: "Tom Johnson"
  score: 100

mike =
  name: "Mike Johnson"
  score: 50

TomModel = null
MikeModel = null

beforeEach (done) ->
  User.create tom, (err, doc) ->
    return done err if err?
    TomModel = doc
    User.create mike, (err, doc) ->
      return done err if err?
      MikeModel = doc
      TomModel.friends.push MikeModel
      TomModel.set 'bestFriend', MikeModel
      MikeModel.friends.push TomModel
      MikeModel.set 'bestFriend', TomModel

      TomModel.save (err) ->
        return done err if err?
        MikeModel.save (err) ->
          return done err if err?
          done()

afterEach db.wipe

describe 'crudify integration', ->

  # collection
  describe 'GET /users', ->
    it 'should return all users', (done) ->
      opt =
        method: "GET"
        json: true
        uri: "http://localhost:#{PORT}/users"
        
      request opt, (err, res, body) ->
        should.not.exist err
        res.statusCode.should.equal 200
        should.exist body
        Array.isArray(body).should.equal true
        body.length.should.equal 2
        done()

    it 'should error with no read', (done) ->
      opt =
        method: "GET"
        json: true
        uri: "http://localhost:#{PORT}/users"
        headers:
          hasRead: "false"
      request opt, (err, res, body) ->
        should.not.exist err
        res.statusCode.should.equal 401
        should.exist body
        should.exist body.error
        should.exist body.error.message
        body.error.message.should.equal "Not authorized"
        done()

    it 'should return all users with limit', (done) ->
      opt =
        method: "GET"
        json: true
        uri: "http://localhost:#{PORT}/users?limit=1"
        
      request opt, (err, res, body) ->
        should.not.exist err
        res.statusCode.should.equal 200
        should.exist body
        Array.isArray(body).should.equal true
        body.length.should.equal 1
        done()

    it 'should return all users with mike as a friend', (done) ->
      opt =
        method: "GET"
        json: true
        uri: "http://localhost:#{PORT}/users?bestFriend=#{MikeModel._id}"
        
      request opt, (err, res, body) ->
        should.not.exist err
        res.statusCode.should.equal 200
        should.exist body
        Array.isArray(body).should.equal true
        body.length.should.equal 1
        body[0].name.should.equal TomModel.name
        done()

    it 'should return all users with skip', (done) ->
      opt =
        method: "GET"
        json: true
        uri: "http://localhost:#{PORT}/users?skip=1"
        
      request opt, (err, res, body) ->
        should.not.exist err
        res.statusCode.should.equal 200
        should.exist body
        Array.isArray(body).should.equal true
        body.length.should.equal 1
        done()

    it 'should return all users with sort descending', (done) ->
      opt =
        method: "GET"
        json: true
        uri: "http://localhost:#{PORT}/users?sort=score"
        
      request opt, (err, res, body) ->
        should.not.exist err
        res.statusCode.should.equal 200
        should.exist body
        Array.isArray(body).should.equal true
        body.length.should.equal 2
        (body[0].score <= body[1].score).should.equal true
        done()

    it 'should return all users with sort ascending', (done) ->
      opt =
        method: "GET"
        json: true
        uri: "http://localhost:#{PORT}/users?sort=-score"
        
      request opt, (err, res, body) ->
        should.not.exist err
        res.statusCode.should.equal 200
        should.exist body
        Array.isArray(body).should.equal true
        body.length.should.equal 2
        (body[0].score >= body[1].score).should.equal true
        done()

    it 'should return all users with populate of one field', (done) ->
      opt =
        method: "GET"
        json: true
        uri: "http://localhost:#{PORT}/users?populate=bestFriend"
        
      request opt, (err, res, body) ->
        should.not.exist err
        res.statusCode.should.equal 200
        should.exist body
        Array.isArray(body).should.equal true
        body.length.should.equal 2
        should.exist body[0].bestFriend
        should.exist body[0].bestFriend.score
        should.exist body[1].bestFriend
        should.exist body[1].bestFriend.score
        done()

    it 'should return all users with populate of two fields', (done) ->
      opt =
        method: "GET"
        json: true
        uri: "http://localhost:#{PORT}/users?populate=bestFriend&populate=friends"
        
      request opt, (err, res, body) ->
        should.not.exist err
        res.statusCode.should.equal 200
        should.exist body
        Array.isArray(body).should.equal true
        body.length.should.equal 2
        should.exist body[0].bestFriend
        should.exist body[0].bestFriend.score
        should.exist body[1].bestFriend
        should.exist body[1].bestFriend.score
        should.exist body[0].friends[0]
        should.exist body[0].friends[0].score
        should.exist body[1].friends[0]
        should.exist body[1].friends[0].score
        done()

  describe 'POST /users', ->
    it 'should create a user', (done) ->
      opt =
        method: "POST"
        json:
          name: "New Guy"
        uri: "http://localhost:#{PORT}/users"
        
      request opt, (err, res, body) ->
        should.not.exist err
        res.statusCode.should.equal 201
        should.exist body
        body.name.should.equal "New Guy"
        body.score.should.equal 0
        done()

    it 'have a validation error if name is blank', (done) ->
      opt =
        method: "POST"
        json:
          name: ""
        uri: "http://localhost:#{PORT}/users"
        
      request opt, (err, res, body) ->
        should.not.exist err
        res.statusCode.should.equal 500
        should.exist body
        body.error.should.eql
          message: 'Validation failed'
          name: 'ValidationError'
          errors: 
            name: 
              message: 'Validator "required" failed for path name with value ``'
              name: 'ValidatorError'
              path: 'name'
              type: 'required'
              value: ''
        done()

  # static methods
  describe 'GET /users/search', ->
    it 'should call the static method', (done) ->
      opt =
        method: "GET"
        json: true
        uri: "http://localhost:#{PORT}/users/search?q=test"
        
      request opt, (err, res, body) ->
        should.not.exist err
        res.statusCode.should.equal 200
        should.exist body
        should.exist body.query
        body.query.should.eql 'test'
        done()

  # single item
  describe 'GET /users/:id', ->
    it 'should return user', (done) ->
      opt =
        method: "GET"
        json: true
        uri: "http://localhost:#{PORT}/users/#{TomModel._id}"
        
      request opt, (err, res, body) ->
        should.not.exist err
        res.statusCode.should.equal 200
        should.exist body
        should.exist body.name
        body.name.should.equal TomModel.name
        body.score.should.equal TomModel.score
        body.bestFriend.should.equal String MikeModel._id
        done()

    it 'should return error on invalid authorization', (done) ->
      opt =
        method: "GET"
        json: true
        headers:
          hasRead: 'false'
        uri: "http://localhost:#{PORT}/users/#{TomModel._id}"
        
      request opt, (err, res, body) ->
        should.not.exist err
        res.statusCode.should.equal 401
        should.exist body
        should.exist body.error
        should.exist body.error.message
        body.error.message.should.equal "Not authorized"
        done()

    it 'should return user with populate', (done) ->
      opt =
        method: "GET"
        json: true
        uri: "http://localhost:#{PORT}/users/#{TomModel._id}?populate=bestFriend"
        
      request opt, (err, res, body) ->
        should.not.exist err
        res.statusCode.should.equal 200
        should.exist body
        should.exist body.name
        body.name.should.equal TomModel.name
        body.score.should.equal TomModel.score
        body.bestFriend.name.should.equal MikeModel.name
        body.bestFriend.score.should.equal MikeModel.score
        done()

  describe 'PATCH /users/:id', ->
    it 'should update user', (done) ->
      opt =
        method: "PATCH"
        uri: "http://localhost:#{PORT}/users/#{TomModel._id}"
        json:
          score: 9001
        
      request opt, (err, res, body) ->
        should.not.exist err
        res.statusCode.should.equal 200
        should.exist body
        should.exist body.name
        body.name.should.equal TomModel.name
        body.score.should.equal 9001
        done()

    it 'should return error on no read', (done) ->
      opt =
        method: "PATCH"
        uri: "http://localhost:#{PORT}/users/#{TomModel._id}"
        json:
          score: 9001
        headers:
          hasRead: 'false'

      request opt, (err, res, body) ->
        should.not.exist err
        res.statusCode.should.equal 401
        should.exist body
        should.exist body.error
        should.exist body.error.message
        body.error.message.should.equal "Not authorized"
        done()

    it 'should return error on no write', (done) ->
      opt =
        method: "PATCH"
        uri: "http://localhost:#{PORT}/users/#{TomModel._id}"
        json:
          score: 9001
        headers:
          hasWrite: 'false'
        
      request opt, (err, res, body) ->
        should.not.exist err
        res.statusCode.should.equal 401
        should.exist body
        should.exist body.error
        should.exist body.error.message
        body.error.message.should.equal "Not authorized"
        done()

    it 'should return error on no write for specific field', (done) ->
      opt =
        method: "PATCH"
        uri: "http://localhost:#{PORT}/users/#{TomModel._id}"
        json:
          password: "test"
        
      request opt, (err, res, body) ->
        should.not.exist err
        res.statusCode.should.equal 401
        should.exist body
        should.exist body.error
        should.exist body.error.message
        body.error.message.should.equal "Not authorized"
        done()

  describe 'PUT /users/:id', ->
    it 'should update user', (done) ->
      opt =
        method: "PUT"
        uri: "http://localhost:#{PORT}/users/#{TomModel._id}"
        json:
          name: "Rob"
        
      request opt, (err, res, body) ->
        should.not.exist err
        res.statusCode.should.equal 200
        should.exist body
        should.exist body.name
        body.name.should.equal "Rob"
        body.score.should.equal 0
        done()

    it 'should not update reset field with no write', (done) ->
      opt =
        method: "PUT"
        uri: "http://localhost:#{PORT}/users/#{TomModel._id}"
        json:
          name: "Rob"

      request opt, (err, res, body) ->
        should.not.exist err
        res.statusCode.should.equal 200
        should.exist body
        should.exist body.name
        body.name.should.equal "Rob"
        body.score.should.equal 0
        body.password.should.equal "pass123"
        done()

    it 'should error on field change with no write', (done) ->
      opt =
        method: "PUT"
        uri: "http://localhost:#{PORT}/users/#{TomModel._id}"
        json:
          name: "Rob"
          password: "jah"

      request opt, (err, res, body) ->
        should.not.exist err
        res.statusCode.should.equal 401
        should.exist body
        should.exist body.error
        should.exist body.error.message
        body.error.message.should.equal "Not authorized"
        done()

    it 'should return error on no read', (done) ->
      opt =
        method: "PUT"
        uri: "http://localhost:#{PORT}/users/#{TomModel._id}"
        json:
          name: "Rob"
        headers:
          hasRead: 'false'
        
      request opt, (err, res, body) ->
        should.not.exist err
        res.statusCode.should.equal 401
        should.exist body
        should.exist body.error
        should.exist body.error.message
        body.error.message.should.equal "Not authorized"
        done()

    it 'should return error on no write', (done) ->
      opt =
        method: "PUT"
        uri: "http://localhost:#{PORT}/users/#{TomModel._id}"
        json:
          name: "Rob"
        headers:
          hasWrite: 'false'
        
      request opt, (err, res, body) ->
        should.not.exist err
        res.statusCode.should.equal 401
        should.exist body
        should.exist body.error
        should.exist body.error.message
        body.error.message.should.equal "Not authorized"
        done()

  describe 'DELETE /users/:id', ->
    it 'should update user', (done) ->
      opt =
        method: "DELETE"
        json: true
        uri: "http://localhost:#{PORT}/users/#{TomModel._id}"
        
      request opt, (err, res, body) ->
        should.not.exist err
        res.statusCode.should.equal 200
        should.exist body
        should.exist body.name
        body.name.should.equal TomModel.name
        body.score.should.equal TomModel.score
        done()

    it 'should return error on no read', (done) ->
      opt =
        method: "DELETE"
        json: true
        uri: "http://localhost:#{PORT}/users/#{TomModel._id}"
        headers:
          hasDelete: 'false'
        
      request opt, (err, res, body) ->
        should.not.exist err
        res.statusCode.should.equal 401
        should.exist body
        should.exist body.error
        should.exist body.error.message
        body.error.message.should.equal "Not authorized"
        done()

    it 'should return error on no write', (done) ->
      opt =
        method: "DELETE"
        json: true
        uri: "http://localhost:#{PORT}/users/#{TomModel._id}"
        headers:
          hasDelete: 'false'
        
      request opt, (err, res, body) ->
        should.not.exist err
        res.statusCode.should.equal 401
        should.exist body
        should.exist body.error
        should.exist body.error.message
        body.error.message.should.equal "Not authorized"
        done()

        
  ###
  describe 'GET /users/:id/bestFriend', ->
    it 'should return populated friend', (done) ->
      opt =
        method: "GET"
        json: true
        uri: "http://localhost:#{PORT}/users/#{TomModel._id}/bestFriend"
        
      request opt, (err, res, body) ->
        should.not.exist err
        res.statusCode.should.equal 200
        should.exist body
        should.exist body.name
        body.name.should.equal MikeModel.name
        body.score.should.equal MikeModel.score
        done()

  describe 'PUT /users/:id/bestFriend', ->
    it 'should modify the dbref', (done) ->
      opt =
        method: "PUT"
        body: String(MikeModel._id)
        uri: "http://localhost:#{PORT}/users/#{TomModel._id}/bestFriend"
      
      request opt, (err, res, body) ->
        console.log body
        should.not.exist err
        res.statusCode.should.equal 200
        should.exist body
        should.exist body.name
        body.name.should.equal TomModel.name
        body.score.should.equal TomModel.score
        body.bestFriend.should.equal String MikeModel._id
        done()
  ###
  
  describe 'GET /users/:id/findWithSameName', ->
    it 'should return user', (done) ->
      opt =
        method: "GET"
        json: true
        uri: "http://localhost:#{PORT}/users/#{TomModel._id}/findWithSameName?q=test"
        
      request opt, (err, res, body) ->
        should.not.exist err
        res.statusCode.should.equal 200
        should.exist body
        should.exist body.name
        should.exist body.query
        body.name.should.equal TomModel.name
        body.query.should.equal 'test'
        done()