# ASH Ollama Helper

This repo contains a helper script to help provide custom context files for your local Ollama LLMs. 

## Dependencies
- Ollama: You can install Ollama by following the instructions on their official website: https://ollama.com/docs/installation
- fzf: fzf is a command-line fuzzy finder. You can install fzf by following the instructions on their official GitHub repository: https://github.com/junegunn/fzf

## Usage
- Copy the `.ollama_prompt.sh` file to you home directory. 
- Make the script executable by running the following command in your terminal:

```bash
chmod +x ~/.ollama_prompt.sh
``` 

- To add your own custom context files, simply create a new `.txt` file and add it to a new directoy called `~/.ollama_contexts/` in your root directory with the desired content. 
- When you run the `ollama_prompt` command in the terminal, it will prompt you to select a downloaded LLM, then it will prompt you to select a context file from the `~/.ollama_contexts/` directory, and finally it will ask you to enter your prompt. The script will then combine the selected context with your prompt.

## TODO
- [ ] Allow continuous conversation with the LLM.
- [ ] Better code syntax formatting.
- [ ] Allow easy copy/paste for code blocks.