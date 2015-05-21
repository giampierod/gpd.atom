'Copyright (c) 2014 Yoshiori SHOJI. The license text can be found in the
`LICENSE_SHOJI` file provided with this project.'

{View} = require 'atom-space-pen-views'

module.exports =
class PomodoroView extends View
  @content: ->
    @div class: "pomodoro inline-block", =>
      @span style: "color: red", "🍅"
      @span outlet: 'statusText'

  initialize: (timer) ->
    timer.setUpdateCallback(@update)

  destroy: ->
    @detach()

  update: (status) =>
    @statusText.text(status)
