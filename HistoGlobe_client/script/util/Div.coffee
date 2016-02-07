window.HG ?= {}

# ============================================================================
# <div> element, its DOM element and its object counterpart inside code
# parameters:
#   id        'id' of div in dom
#   classes   ['className1', 'className2', ...] (if many)
#   hidden    true (optional, if not stated, not hidden)

class HG.Div

  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  # ============================================================================
  constructor: (id=null, classes=[], hidden=false) ->

    # error handling: if only one class as string given, make it an array
    classes = [classes] if typeof classes is 'string'

    @_obj = document.createElement 'div'      # creates element
    @_obj.id = id if id                       # sets id
    @_dom = $(@_obj)                          # saves DOM element
    @_dom.hide() if hidden                    # hides element if given
    @_dom.addClass c for c in classes         # adds all classes

  # ============================================================================
  append: (child) ->    @_obj.appendChild child.obj()
  prepend: (child) ->   @_obj.insertBefore child.obj(), @_obj.firstChild

  # ============================================================================
  obj: () ->            @_obj
  dom: () ->            @_dom