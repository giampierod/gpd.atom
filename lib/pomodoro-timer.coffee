'''
Copyright (c) 2014 Yoshiori SHOJI

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
"Software"), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
'''

events = require 'events'

module.exports =
class PomodoroTimer extends events.EventEmitter

  # TASK_TIME = 25 * 60 * 1000
  # REST_TIME = 5 * 60 * 1000
  TASK_TIME = 5 * 1000
  REST_TIME = 10 * 1000

  start: (text) ->
    @startTime = new Date()
    @text = text
    @timer = setInterval ( => @step(TASK_TIME,"TASK") ), 1000

  abort: ->
    @status = "Aborted (#{@text})"
    @stop()

  finish: ->
    @status = "Finished (#{@text})"
    @stop()

  start_rest: ->
    @status = "Rest"
    @stop()
    @startTime = new Date()
    @timer = setInterval ( => @step(REST_TIME,"REST") ), 1000

  stop: ->
    clearTimeout @timer
    @updateCallback(@status)

  step: (time_length, type) ->
    time = (time_length - (new Date() - @startTime)) / 1000
    rest = ""
    if type == "REST"
      rest = "Rest for "
    if time <= 0 & type == "TASK"
      @emit 'rest'
    else if time <= 0 & type == "REST"
      @emit 'finished'
    else if time > 0
      min = @zeroPadding(Math.floor(time / 60))
      sec = @zeroPadding(Math.floor(time % 60))
      @status = "#{min}:#{sec} #{rest}#{@text}"
      @updateCallback(@status)

  zeroPadding: (num) ->
    ("0" + num).slice(-2)

  setUpdateCallback: (fn) ->
    @updateCallback = fn
