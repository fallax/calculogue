# Literate Coffeescript TISBL interpreter

This is an experimental literate Coffeescript intepreter. This does not yet implement all of the features described in the main spec.

## Utility functions

For the purposes of making the rest of the code slightly clearer, we define a simple "contains" method that checks a list to see if contains an item.

    Array.prototype.contains = (element) -> (return true) for item in this when item is element; false;

(Eventually we'll get [Array.includes](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Array/includes) in JavaScript to do this... but it doesn't exist yet.)

## Invoking the interpreter

A TISBL interpreter takes in some input code, and modifies an "environment" that it can write to and read from.

To execute the code we create a "context" - a set of several different stacks - and put the input code into the "execution" stack. To run the code, we read code in from the execution stack, and based on the read values, we update the stacks.

    window.tisbl = (input, environment) ->
      code = load(input);

      root =
        primary: []
        secondary: []
        execution: code
        input: null
        output: null
        parent: null

      # Reads out code from the execution stack and executes it until there is none left.
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

When executing a context, we attempt to execute each token in order until there is none left, or an error occurs that requires us to stop execution completely.

Each token is parsed to understand it. Based on values found we create a context for the token to be executed in. Finally, based on the type of token, we execute the token in that context.

    executeContext = (context, environment) ->
      # Variable to keep track of whether a fatal error has occurred.
      halting = false

      while not halting and context.execution.length > 0

        # Find a token to execute
        token = context.execution.pop()
        
        continue if token.length < 1 # ignore any 0 length tokens completely

        parsedToken = parseToken token
        newContext = makeContext parsedToken, context

        if not tokenTypes[parsedToken.tokenIdentifier]
          # this token is gibberish - throw an error
          environment.output += "* Error: Couldn't read token '" + token + "' - did you forget ', #, or \\ ?"
          halting = true
        else
          # execute the code for this token in the correct context
          halting = tokenTypes[parsedToken.tokenIdentifier] parsedToken.message, newContext, environment

## Turning tokens into contexts

First we need to be able to read in the values from a token.

Each token consists of, in order:

Either:

(verb identifier)(stack identifier?)(body)(stack identifier?)

Or:

(stack identifier?)(noun identifier)(body)

    parseToken = (token) ->
      # return the details of what characters we got in each slot
      parsedToken = {}

      # Check if the token is a verb
      verb = token[0] is "\\"

      if verb
        parsedToken.tokenIdentifier = token[0]
        parsedToken.inputStack = tryGetStackIdentifier token[1]
        parsedToken.outputStack = tryGetStackIdentifier token[token.length - 1]
        parsedToken.message = token.substring (if parsedToken.inputStack? and parsedToken.inputStack.length is 1 then 2 else 1), token.length - (if parsedToken.outputStack.length is 1 then 1 else 0)
      else
        parsedToken.inputStack = "" # set this to whatever, used for nothing
        parsedToken.outputStack = tryGetStackIdentifier token[0]
        if parsedToken.outputStack is "" then parsedToken.tokenIdentifier = token[0] else parsedToken.tokenIdentifier = token[1]
        parsedToken.message = token.substring (if parsedToken.outputStack.length is 1 then 2 else 1), token.length

      parsedToken

Next, we need to be able to turn the parsed details of a token into a context. We do this based on the two stack identifiers.

    makeContext = (parsedToken, context) ->
      {
        primary: []
        secondary: []
        execution: []
        input: stackIdentifiers[parsedToken.inputStack] context
        output: stackIdentifiers[parsedToken.outputStack] context, 999
        parent: context.execution
      }

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

Each stack identifier represents a stack within the current context. 

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
