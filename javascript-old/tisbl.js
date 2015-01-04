var verbs = {};
var output = "";

var stdlib = {

	"mv": function (inputStack, outputStack) {
		outputStack.push(inputStack.pop());
	},

	"rm": function (inputStack, outputStack) {
		inputStack.pop();
	},

	"dup": function (inputStack, outputStack) {
		outputStack.push(inputStack[inputStack.length - 1]);
	},

	"swap": function (inputStack, outputStack) {
		var a = inputStack.pop();
		var b = inputStack.pop();
		outputStack.push(a);
		outputStack.push(b);
	},

	"out": function (inputStack, outputStack) {
		output += inputStack.pop();
	},

	"_": function (inputStack, outputStack) {
		outputStack.push(inputStack.pop() + " ");
	},

	"n": function (inputStack, outputStack) {
		outputStack.push(inputStack.pop() + "\n");
	},

	"+": function (inputStack, outputStack) {
		var a = inputStack.pop();
		var b = inputStack.pop();
		outputStack.push(b + a);
	},

	"-": function (inputStack, outputStack) {
		var a = inputStack.pop();
		var b = inputStack.pop();
		outputStack.push(b - a);
	},

	"*": function (inputStack, outputStack) {
		var a = inputStack.pop();
		var b = inputStack.pop();
		outputStack.push(b * a);
	},

	"eq?": function (inputStack, outputStack) {
		var a = inputStack.pop();
		var b = inputStack.pop();
		outputStack.push(b == a ? 1 : 0);
	},

	"not": function (inputStack, outputStack) {
		var a = inputStack.pop();
		outputStack.push(a == 0 ? 1 : 0);
	},

	"verb": function (inputStack, outputStack) {
		var verbName = inputStack.pop();
		var verbLength = inputStack.pop();
		var verbStack = [];

		for (var i = 0; i < verbLength; i++)
		{
			verbStack.push(inputStack.pop());
		}	

		verbs[verbName] = verbStack;
	},

	"multipop": function (inputStack, outputStack) {

		var length = inputStack.pop();

		for (var i = 0; i < length; i++)
		{
			outputStack.push(inputStack.pop());
		}
	},

	"if": function (inputStack, outputStack) {

		var length = inputStack.pop();
		var stack = [];

		for (var i = 0; i < length; i++)
		{
			stack.push(inputStack.pop());
		}

		// Start a new context
		var context = ({
			"primary": [], 
			"secondary": [],
			"execution": stack, 
			"input": inputStack, 
			"output": outputStack, 
			"parent": null // TODO: IS THIS CORRECT?
		});

		var condition = inputStack.pop();

		if (condition != 0)
		{
			// Execute that context
			console.log("running if statement (" + condition + ")");
			executeContext(context, output);
		}
		else
		{
			console.log("not running if statement (" + condition + ")");
		}
	},

	"while": function (inputStack, outputStack) {

		console.log("running while loop");
		var length = inputStack.pop();
		var stack = [];

		for (var i = 0; i < length; i++)
		{
			stack.push(inputStack.pop());
		}

		while (true)
		{
			var condition = inputStack.pop();
			if (condition == 0) 
			{ 
				console.log("breaking out of while..." + condition);
				break; 
			}
			else
			{
				console.log("continuing while: " + condition);
				// Start a new context
				var context = ({
					"primary": [], 
					"secondary": [],
					"execution": stack.slice(0), 
					"input": inputStack, 
					"output": outputStack, 
					"parent": null // TODO: IS THIS CORRECT?
				});

				executeContext(context, output);
			}
		}
	}
};

function tisbl(input)
{
	output = "";

	var lines = input.split("\n");
	input = "";

	for (var i in lines)
	{
		var line = lines[i];

		// Ignore blank lines
		if (line.length < 1) { continue; }

		// Ignore lines that contain just comments
		if (line[0] == "%") { continue; }

		// Remove any comments if they exist
		if (line.indexOf(" %") > -1)
		{
			// TODO: do this in a better way that can cope with other whitespace characters
			input += line.substr(0, line.indexOf(" %")) + " ";
		}
		else
		{
			input += line + " ";
		}
		
	}

	var splitInput = input.split(" ");

	splitInput.reverse();

	// initialise root stack
	var root = {"primary":[], "secondary":[], "execution":splitInput, "input": null, "output": null, "parent": null};

	outputContext = executeContext(root, output);

	console.log(outputContext);
	
	return "done.";
}

function parseStackCharacter(character, context, paramStack)
{
	switch (character)
	{
		case ".": return paramStack; // Verb input stack - copy parent context
		case ":": return context.secondary; // Secondary data stack
		case ",": return context.execution; // Execution stack
		case ";": return context.parent; // Parent execution stack
		default: return context.primary; // Primary data stack
	}
}

function filterStackCharacter(character)
{
	switch (character)
	{
		case ".":
		case ":":
		case ",":
		case ";": return "";
		default: return character;
	}
}

function executeContext(context)
{
	var halting = false;

	while (!halting && context.execution.length > 0)
	{
		// Find a token to execute
		var token = context.execution.pop();
		if (token.length < 1)
		{
			continue; // ignore any 0 length tokens completely
		}

		// Check if the token is a verb; if so, strip the leading \ character
		var verb = false;
		if (token[0] == "\\")
		{
			// The token is a verb
			verb = true;
			var token = token.substr(1);
		}

		// Check to see if the start or end characters are stack characters; 
		// if so, blank them out, and return the correct stack
		
		var inputStack = null;
		var outputStack = null;

		var start = token.substr(0, 1);
		var end = token.length > 1 ? token.substr(token.length - 1, 1) : "";
		var middle = token.length > 2 ? token.substr(1, token.length - 2) : "";
		
		if (verb)
		{
			inputStack = parseStackCharacter(start, context, context.input);
			outputStack = parseStackCharacter(end, context, context.output);
			token = filterStackCharacter(start) + middle + filterStackCharacter(end);
		}
		else
		{
			inputStack = null;
			outputStack = parseStackCharacter(start, context, context.output);
			token = filterStackCharacter(start) + middle + end;
		}

		// Execute the token
		if (verb)
		{
			console.log("running: " + token);
			console.log("primary: " + context.primary);
			console.log("secondary: " + context.secondary);
			console.log("input: " + context.input);
			console.log("execution: " + context.execution);

			if (verbs[token])
			{
				// The user has defined a verb with this token as the name, execute that

				// Start a new context
				var verbContext = ({
					"primary": [], 
					"secondary": [], 
					"execution": verbs[token].slice(0), 
					"input": inputStack, 
					"output": outputStack, 
					"parent": context.execution
				});

				// Execute that context
				executeContext(verbContext, output);
			}
			else if (stdlib[token])
			{
				// There is an entry for this in the built in functions list, execute that
				stdlib[token](inputStack, outputStack);
			}
			else
			{
				// This verb doesn't seem to be defined, throw an error
				output += "* Error: Unknown verb '" + token + "'";
				halting = true;
			}
		}
		else
		{
			// Parse the string, int or float into a real value.
			switch (token.substr(0, 1))
			{
				case "#": 
					var value = (token.indexOf(".") > -1) ? parseFloat(token.substr(1)) : parseInt(token.substr(1));
					outputStack.push(value);
					break;

				case "'": outputStack.push(token.substr(1)); break;

				default: 
					output += "* Error: Couldn't read noun '" + token + "' - did you forget ', #, or \\ ?";
					halting = true;
			}
		}
	}

	return context;
}