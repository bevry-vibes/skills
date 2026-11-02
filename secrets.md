# secrets

Never probe for tokens or secrets.

This rule applies to every agent and every task. A secret is any credential, token, key, password, session cookie, or private value.

## documented locations

Use a secret only from the location that the project documents for it. A documented location is an environment variable, a local file, a secret store, or a CI secret that the project names in its instructions or configuration.

Do not use any other source.

If a documented location is missing a key, stop and prompt the user for options. Do not search for a replacement. Offer choices such as:

- set the key in the documented location
- provide a token with the minimum scope
- choose a path that does not need the key

Wait for the answer before you continue.

## prohibited probing

Do not:

- search home directories, shell history, editor history, browser profiles, keychains, or password managers
- read unrelated configuration files, other repositories, or system credential stores
- try a token from a different project, environment, or service
- guess a key name, path, or value
- print, copy, log, or commit a secret
- retry a command with a credential that you found outside the documented location

These actions bypass access control. They can expose unrelated secrets. They make the result impossible to audit.

## missing credentials

When a command fails because a secret is absent, do this:

1. Read the project documentation for the documented location.
2. Confirm that the variable or file is absent. Do not show its value.
3. Stop the task.
4. Ask the user for one of the options above.
5. Continue only after the user answers.

Do not use a fallback credential. Do not change the task to avoid the secret unless the user agrees.

## handling

- Use the least privilege that the task needs.
- Keep a secret only in memory for the task.
- Do not write a secret to a file, a log, a plan, a commit, or a chat message.
- If a secret appears in output, stop and tell the user. Do not repeat it.
- If a secret is committed or logged, tell the user to rotate it.
