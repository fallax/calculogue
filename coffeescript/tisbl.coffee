window.tisbl = (input, environment) ->
  lines = input.split("\n")
  input = ""

  for line in lines when line.length > 0 and line[0] isnt "%"  
    # Remove any comments if they exist
    if line.indexOf(" %") > -1
      # TODO: do this in a better way that can cope with other whitespace characters
      input += line.substr(0, line.indexOf(" %")) + " "
    else
      input += line + " "

  splitInput = input.split(" ")
  splitInput.reverse()
  
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

parseStackCharacter = (character, context, paramStack) ->
  switch character
    when "." then paramStack # Verb input stack - copy parent context
    when ":" then context.secondary # Secondary data stack
    when "," then context.execution # Execution stack
    when ";" then context.parent # Parent execution stack
    else context.primary # Primary data stack
      
filterStackCharacter = (character) ->
  switch character
    when ".", ":", ",", ";" then ""
    else character

executeContext = (context, environment) ->
  halting = false
  while not halting and context.execution.length > 0
    
    # Find a token to execute
    token = context.execution.pop()
    continue if token.length < 1 # ignore any 0 length tokens completely
    
    # Check if the token is a verb
    verb = token[0] is "\\"

    # if so, strip the leading \ character
    if verb then token = token.substr(1)
    
    # Check to see if the start or end characters are stack characters; 
    # if so, blank them out, and return the correct stack
    inputStack = null
    outputStack = null
    start = token.substr(0, 1)
    end = (if token.length > 1 then token.substr(token.length - 1, 1) else "")
    middle = (if token.length > 2 then token.substr(1, token.length - 2) else "")

    if verb
      inputStack = parseStackCharacter(start, context, context.input)
      outputStack = parseStackCharacter(end, context, context.output)
      token = filterStackCharacter(start) + middle + filterStackCharacter(end)
    else
      inputStack = null
      outputStack = parseStackCharacter(start, context, context.output)
      token = filterStackCharacter(start) + middle + end
    
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