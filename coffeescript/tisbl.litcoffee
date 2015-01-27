# Literate Coffeescript TISBL interpreter

This is an experimental literate Coffeescript intepreter. This does not yet implement all of the features described in the main spec.

## Utility functions

For the purposes of making the rest of the code slightly clearer, we define a simple "contains" method that checks a list to see if contains an item.

    Array.prototype.contains = (element) -> (return true) for item in this when item is element; false;

## Invoking the interpreter

TISBL is always interpreted within some kind of environment that provides a standard output to write to.

    window.tisbl = (input, environment) ->
      splitInput = load(input);
      
      # initialise root stack
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
          leadingStack = null
          trailingStack = tryGetStackIdentifier token[0]
          if trailingStack is "" then tokenIdentifier = token[0] else tokenIdentifier = token[1]
          message = token.substring (if trailingStack.length is 1 then 2 else 1), token.length
       
Before executing the token, we create a context for that token to be executed in. We do this based on the two stack identifiers we received and their positions.

        newContext = 
          primary: []
          secondary: []
          execution: []
          input: parseStackCharacter leadingStack, context
          output: parseStackCharacter trailingStack, context, 999
          parent: context.execution

What we do with the new context depends on the type of token.

Based on the token type identifier, we decide what to do to execute the token.

Token type identifiers are:
* "#": interpret the body as a number - if it contains a ".", a float; otherwise, an int. Push this to the output stack.
* "'": interpret the body as a string. Push the string to the output stack.
* "\": interpret the body as a verb name. Look up the verb name in the verbs table, set the execution stack of the new context to be a copy of the value in the verbs table, and execute that context.

        # Execute the token
        switch tokenIdentifier
          when "#"
            value = (if (message.indexOf(".") > -1) then parseFloat(message) else parseInt(message))
            newContext.output.push value
          
          when "'"
            newContext.output.push message

          when "\\"
            if verbs[message]
              # The user has defined a verb with this token as the name, execute that
              newContext.execution = verbs[message].slice(0)
              
              # Execute that context
              executeContext newContext, environment

            else if stdlib[message]
              # There is an entry for this in the built in functions list, execute that
              stdlib[message] newContext.input, newContext.output, environment
            
            else  
              # This verb doesn't seem to be defined, throw an error
              environment.output += "* Error: Unknown verb '" + message + "'"
              halting = true
          else
            environment.output += "* Error: Couldn't read token '" + message + "' - did you forget ', #, or \\ ?"
            halting = true

      context



### Stack identifiers

Stack identifiers represent:
* ".": if the leading character, the input stack of the parent context; if the trailing character, the output stack of the parent context
* ":": secondary data stack
* ",": execution stack
* ";": parent execution stack
* no identifier: primary data stack

TODO: work out how to get GitHub to understand when I end an unordered list and start actual code

    stackIdentifiers = 
      ".": (context, position) -> (if position is 0 then context.input else context.output),
      ":": (context, position) -> context.secondary,
      ",": (context, position) -> context.execution,
      ";": (context, position) -> context.parent,
      "": (context, position) -> context.primary

    parseStackCharacter = (character, context, position) ->
      #console.log "Loooking up " + character

      if not character? then return null 

      if Object.keys(stackIdentifiers).contains character
        stackIdentifiers[character] context, position
      else 
        context.primary
          
## Getting leading or trailing characters

This is a weird back to front function because I got confused. I should remove it.

    filterStackIdentifier = (character) ->
      if Object.keys(stackIdentifiers).contains character then "" else character

This is a more useful function.

    tryGetStackIdentifier = (character) ->
      if Object.keys(stackIdentifiers).contains character then character else ""

## TISBL built-in functions

    verbs = {}

    stdlib =
      mv: (inputStack, outputStack) -> outputStack.push inputStack.pop()
      rm: (inputStack, outputStack) -> inputStack.pop()
      dup: (inputStack, outputStack) -> outputStack.push inputStack[inputStack.length - 1]
      out: (inputStack, outputStack, environment) -> environment.output += inputStack.pop()
      _: (inputStack, outputStack) -> outputStack.push inputStack.pop() + " "
      n: (inputStack, outputStack) -> outputStack.push inputStack.pop() + "\n"

      swap: (inputStack, outputStack) ->
        outputStack.push inputStack.pop()
        outputStack.push inputStack.pop()

      # Arithmetic - TODO - requires properly implementing the number type in TISBL

      "+": (inputStack, outputStack) ->
        a = inputStack.pop()
        b = inputStack.pop()
        outputStack.push b + a

      "-": (inputStack, outputStack) ->
        a = inputStack.pop()
        b = inputStack.pop()
        outputStack.push b - a

      "*": (inputStack, outputStack) ->
        a = inputStack.pop()
        b = inputStack.pop()
        outputStack.push b * a

      "eq?": (inputStack, outputStack) ->
        a = inputStack.pop()
        b = inputStack.pop()
        outputStack.push (if b is a then 1 else 0)

      not: (inputStack, outputStack) ->
        a = inputStack.pop()
        outputStack.push (if a is 0 then 1 else 0)

      verb: (inputStack, outputStack) ->
        verbName = inputStack.pop()
        verbLength = inputStack.pop()
        verbs[verbName] = (inputStack.pop() for i in [0..verbLength-1])

      multipop: (inputStack, outputStack) ->
        length = inputStack.pop()
        for [0..length]
          outputStack.push inputStack.pop()

      if: (inputStack, outputStack) ->
        length = inputStack.pop()
        stack = (inputStack.pop() for i in [0..(length-1)])

        context = (
          primary: []
          secondary: []
          execution: stack
          input: inputStack
          output: outputStack
          parent: null
        )
        condition = inputStack.pop()
        unless condition is 0
          console.log "running if statement (" + condition + ")"
          executeContext context, output
        else
          console.log "not running if statement (" + condition + ")"

      while: (inputStack, outputStack) ->
        console.log "running while loop"

        length = inputStack.pop()
        stack = (inputStack.pop() for i in [0..(length-1)])

        loop
          condition = inputStack.pop()
          if condition is 0
            console.log "breaking out of while..." + condition
            break
          else
            console.log "continuing while: " + condition
            context = (
              primary: []
              secondary: []
              execution: stack.slice(0)
              input: inputStack
              output: outputStack
              parent: null
            )
            executeContext context, output
