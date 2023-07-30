module app;

import core.sys.windows.windows : HINSTANCE, LPSTR;

import program;
import common;

extern(C) __gshared string[] rt_options = [ "gcopt=gc:precise"];

extern (Windows)
int WinMain(
    HINSTANCE hInstance, 
    HINSTANCE hPrevInstance,
    LPSTR lpCmdLine, 
    int nCmdShow)
{
    return Program.Start(lpCmdLine.FromCString);
}
