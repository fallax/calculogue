# Literate Coffeescript TISBL interpreter

This is an experimental literate Coffeescript intepreter. This does not yet implement all of the features described in the main spec.

## Utility functions

For the purposes of making the rest of the code slightly clearer, we define a simple "contains" method that checks a list to see if contains an item.

    Array.prototype.contains = (element) -> (return true) for item in this when item is element; false;

## Invoking the interpreter

TISBL is always interpreted within some kind of environment that provides a standard output to write to.

    window.tisbl = (input, environment) ->
      splitInput = load(input);
      
      # initialise root context
      root =
        primary: []
        secondary: []
        execution: splitInput
        input: null
        output: null
        parent: null

      outputContext = executeContext(root, environment)
      environment.output

## Loading TISBL code in from a file

TISBL code is a set of lines, seperated by newline characters. 

    load = (rawText) ->
      lines = rawText.split("\n")

Some lines contain comments - we remove them before trying to interpret the code.
      
      trimmedLines = (trimComment line for line in lines)

All linebreaks are ignored after comments have been removed.

      input = trimmedLines.join(" ");

The text read by the interpreter consists of a set of "tokens", seperated by whitespace. Tokens appear in the text in the *opposite* order to that in which they are executed.

      input.split(" ").reverse()

### Removing comments from code

Lines are:

* either, a line to be ignored by the interpreter, which must begin with "%"

* or, text to be read by the interpreter, followed by " %" and a comment

* or, a line to be wholly read by the interpreter.

This method filters out the comment text and just leaves the code that needs to be interpreted.

    trimComment = (line) ->
      if line.indexOf("%") is 0
          return ""
      if line.indexOf(" %") > -1
          line.substr(0, line.indexOf(" %"))
        else
          line

## Executing a context

When executing a context, we attempt to execute each token in order.

    executeContext = (context, environment) ->
      halting = false
      while not halting and context.execution.length > 0

        # Find a token to execute
        token = context.execution.pop()
        
        continue if token.length < 1 # ignore any 0 length tokens completely
        
Each token consists of, in order:

Either:

(verb identifier)(stack identifier?)(body)(stack identifier?)

Or:

(stack identifier?)(noun identifier)(body)

        # Check if the token is a verb
        verb = token[0] is "\\"

        if verb
          tokenIdentifier = token[0]
          leadingStack = tryGetStackIdentifier token[1]
          trailingStack = tryGetStackIdentifier token[token.length - 1]
          message = token.substring (if leadingStack? and leadingStack.length is 1 then 2 else 1), token.length - (if trailingStack.length is 1 then 1 else 0)
        else
          leadingStack = ""
          trailingStack = tryGetStackIdentifier token[0]
          if trailingStack is "" then tokenIdentifier = token[0] else tokenIdentifier = token[1]
          message = token.substring (if trailingStack.length is 1 then 2 else 1), token.length
       
Before executing the token, we create a context for that token to be executed in. We do this based on the two stack identifiers we received and their positions.

        newContext = 
          primary: []
          secondary: []
          execution: []
          input: stackIdentifiers[leadingStack] context
          output: stackIdentifiers[trailingStack] context, 999
          parent: context.execution

Based on the token type identifier, we then execute the token.

        if not tokenTypes[tokenIdentifier]
          # this token is gibberish - throw an error
          environment.output += "* Error: Couldn't read token '" + message + "' - did you forget ', #, or \\ ?"
          halting = true
        else
          # execute the code for this token in the correct context
          halting = tokenTypes[tokenIdentifier] message, newContext, environment

## Execting a token

Token type identifiers are a single character that explain how to execute that token. 

There are three token types: # (number), ' (string), and \ (verb). 

    tokenTypes = 
      "#": (message, newContext, environment) ->
        # interpret the body as a number - either a float (if it has a decimal point), otherwise an integer
        newContext.output.push (if (message.indexOf(".") > -1) then parseFloat(message) else parseInt(message))
        false
      "'": (message, newContext, environment) ->
        # interpret the message as a string literal
        newContext.output.push message
        false
      "\\": (message, newContext, environment) ->
        # interpret the message as a verb name, and try and find it either in the standard library or the user defined verbs
        if not verbs[message] and not stdlib[message]
          environment.output += "No such verb: " + message; return true
        if verbs[message]
          newContext.execution = verbs[message].slice(0)
          executeContext newContext, environment
        if stdlib[message]
          stdlib[message] newContext.input, newContext.output, environment
        false

### Stack identifiers

Stack identifiers represent:
* ".": if the leading character, the input stack of the parent context; if the trailing character, the output stack of the parent context
* ":": secondary data stack
* ",": execution stack
* ";": parent execution stack
* no identifier: primary data stack

For each stack identifier, there is a function that given the context returns the correct stack from that context. 

    stackIdentifiers = 
      ".": (context, position) -> (if position is 0 then context.input else context.output),
      ":": (context) -> context.secondary,
      ",": (context) -> context.execution,
      ";": (context) -> context.parent,
      "": (context) -> context.primary
          
## Getting leading or trailing characters

This function takes a character, and returns a character identifying a stack if it can find one.

    tryGetStackIdentifier = (character) ->
      if Object.keys(stackIdentifiers).contains character then character else ""

## TISBL built-in functions

    # The list of user-defined verbs
    verbs = {}

    # The dictionary of verbs in the standard library
    stdlib =
      mv: (input, ouptut) -> ouptut.push input.pop()
      rm: (input, ouptut) -> input.pop()
      dup: (input, ouptut) -> ouptut.push input[input.length - 1]
      out: (input, ouptut, environment) -> environment.output += input.pop()
      _: (input, ouptut) -> ouptut.push input.pop() + " "
      n: (input, ouptut) -> ouptut.push input.pop() + "\n"

      swap: (input, ouptut) ->
        ouptut.push input.pop()
        ouptut.push input.pop()

      # Arithmetic - TODO - requires properly implementing the number type in TISBL

      "+": (input, ouptut) ->
        a = input.pop()
        b = input.pop()
        ouptut.push b + a

      "-": (input, ouptut) ->
        a = input.pop()
        b = input.pop()
        ouptut.push b - a

      "*": (input, ouptut) ->
        a = input.pop()
        b = input.pop()
        ouptut.push b * a

      "eq?": (input, ouptut) ->
        a = input.pop()
        b = input.pop()
        ouptut.push (if b is a then 1 else 0)

      not: (input, ouptut) ->
        a = input.pop()
        ouptut.push (if a is 0 then 1 else 0)

      verb: (input, ouptut) ->
        verbName = input.pop()
        verbLength = input.pop()
        verbs[verbName] = (input.pop() for i in [0..verbLength-1])

      multipop: (input, ouptut) ->
        length = input.pop()
        for [0..length]
          ouptut.push input.pop()

      if: (input, ouptut) ->
        length = input.pop()
        stack = (input.pop() for i in [0..(length-1)])

        context = (
          primary: []
          secondary: []
          execution: stack
          input: input
          output: ouptut
          parent: null
        )
        condition = input.pop()
        unless condition is 0
          console.log "running if statement (" + condition + ")"
          executeContext context, output
        else
          console.log "not running if statement (" + condition + ")"

      while: (input, ouptut) ->
        console.log "running while loop"

        length = input.pop()
        stack = (input.pop() for i in [0..(length-1)])

        loop
          condition = input.pop()
          if condition is 0
            console.log "breaking out of while..." + condition
            break
          else
            console.log "continuing while: " + condition
            context = (
              primary: []
              secondary: []
              execution: stack.slice(0)
              input: input
              output: ouptut
              parent: null
            )
            executeContext context, output
