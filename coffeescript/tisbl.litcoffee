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

one "token type identifier"
a body.

        # Check if the token is a verb
        verb = token[0] is "\\"

        # if so, strip the leading \ character
        if verb then token = token.substr(1)
        
The body is a string of characters, as follows:

if the token type is "\": zero or one "stack identifier"s,
one or more characters that are the "body" of the token,
zero or one "stack identifier"s

        # Check to see if the start or end characters are stack characters; 
        # if so, blank them out, and return the correct stack
        inputStack = null
        outputStack = null
        start = token.substr(0, 1)
        end = (if token.length > 1 then token.substr(token.length - 1, 1) else "")
        middle = (if token.length > 2 then token.substr(1, token.length - 2) else "")

        if verb
          inputStack = parseStackCharacter(start, context, 0)
          outputStack = parseStackCharacter(end, context, 999)
          token = filterStackIdentifier(start) + middle + filterStackIdentifier(end)
        else
          inputStack = null
          outputStack = parseStackCharacter(start, context, 999)
          token = filterStackIdentifier(start) + middle + end

Before executing the token, we create a context for that token to be executed in. We do this based on the two stack identifiers we received and their positions.

What we do with the new context depends on the type of token.

Based on the token type identifier, we decide what to do to execute the token.

Token type identifiers are:
* "#": interpret the body as a number - if it contains a ".", a float; otherwise, an int. Push this to the output stack.
* "'": interpret the body as a string. Push the string to the output stack.
* "\": interpret the body as a verb name. Look up the verb name in the verbs table, set the execution stack of the new context to be a copy of the value in the verbs table, and execute that context.

        # Execute the token
        if verb
          if verbs[token]
            # The user has defined a verb with this token as the name, execute that
            
            # Start a new context
            verbContext = (
              primary: []
              secondary: []
              execution: verbs[token].slice(0)
              input: inputStack
              output: outputStack
              parent: context.execution
            )
            
            # Execute that context
            executeContext verbContext, environment
          else if stdlib[token]
            
            # There is an entry for this in the built in functions list, execute that
            stdlib[token] inputStack, outputStack, environment
          else
            
            # This verb doesn't seem to be defined, throw an error
            environment.output += "* Error: Unknown verb '" + token + "'"
            halting = true
        else
          
          # Parse the string, int or float into a real value.
          switch token.substr(0, 1)
            when "#"
              value = (if (token.indexOf(".") > -1) then parseFloat(token.substr(1)) else parseInt(token.substr(1)))
              outputStack.push value
            when "'"
              outputStack.push token.substr(1)
            else
              environment.output += "* Error: Couldn't read noun '" + token + "' - did you forget ', #, or \\ ?"
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
      console.log "Loooking up " + character
      if Object.keys(stackIdentifiers).contains character
        stackIdentifiers[character] context, position
      else 
        context.primary
          
## Getting leading or trailing characters

    filterStackIdentifier = (character) ->
      if Object.keys(stackIdentifiers).contains character then "" else character

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
