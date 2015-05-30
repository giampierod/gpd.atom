Todos = require '../lib/todos'

describe "Todos", ->
  [workspaceElement, activationPromise] = []

  beforeEach ->
    workspaceElement = atom.views.getView(atom.workspace)
    activationPromise = atom.packages.activatePackage('gpd')

  describe 'when the gpd:toggle-pomodoro event is triggered', ->
    it 'starts the ticktack sound track', ->
      atom.workspace.open('../docs/examples/Test.GPD')
      atom.commands.dispatch workspaceElement, 'gpd:toggle-pomdoro'


      waitsForPromise ->
        activationPromise
          runs ->
            expect(workspaceElement.querySelector('.sample')).toExist()

            sampleElement = workspaceElement.querySelector('.sample')
            expect(sampleElement).toExist()

            samplePanel = atom.workspace.panelForItem(sampleElement)
            expect(samplePanel.isVisible()).toBe true
            atom.commands.dispatch workspaceElement, 'sample:toggle'
            expect(samplePanel.isVisible()).toBe false

  describe "when the sample:toggle event is triggered", ->
    it "hides and shows the modal panel", ->
      # Before the activation event the view is not on the DOM, and no panel
      # has been created
      expect(workspaceElement.querySelector('.sample')).not.toExist()

      # This is an activation event, triggering it will cause the package to be
      # activated.
      atom.commands.dispatch workspaceElement, 'sample:toggle'

      waitsForPromise ->
        activationPromise

      runs ->
        expect(workspaceElement.querySelector('.sample')).toExist()

        sampleElement = workspaceElement.querySelector('.sample')
        expect(sampleElement).toExist()

        samplePanel = atom.workspace.panelForItem(sampleElement)
        expect(samplePanel.isVisible()).toBe true
        atom.commands.dispatch workspaceElement, 'sample:toggle'
        expect(samplePanel.isVisible()).toBe false

    it "hides and shows the view", ->
      # This test shows you an integration test testing at the view level.

      # Attaching the workspaceElement to the DOM is required to allow the
      # `toBeVisible()` matchers to work. Anything testing visibility or focus
      # requires that the workspaceElement is on the DOM. Tests that attach the
      # workspaceElement to the DOM are generally slower than those off DOM.
      jasmine.attachToDOM(workspaceElement)

      expect(workspaceElement.querySelector('.sample')).not.toExist()

      # This is an activation event, triggering it causes the package to be
      # activated.
      atom.commands.dispatch workspaceElement, 'sample:toggle'

      waitsForPromise ->
        activationPromise

      runs ->
        # Now we can test for view visibility
        sampleElement = workspaceElement.querySelector('.sample')
        expect(sampleElement).toBeVisible()
        atom.commands.dispatch workspaceElement, 'sample:toggle'
        expect(sampleElement).not.toBeVisible()
