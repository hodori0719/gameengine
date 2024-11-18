/// Run with: 'dub'
import std.stdio;
import core.stdc.stdlib;
import gameapplication;

// Entry point to program
void main(string[] args)
{
    if(args.length < 1){
        writeln("usage: dub");
        exit(1);
    }else{
        writeln("Starting with args:\n",args);
    }

	GameApplication app = GameApplication("Spotted Invaders");
	app.RunLoop();
}
