//Simple glut demo implementing PT in vertex shader
//based on: http://www.sandia.gov/~kmorel/documents/gator/

#include <gl/glew.h>
#include <gl/wglew.h>
#include <GL/freeglut.h>
#include <iostream>
#include <fstream>
#include <cmath>
#include <string>
#include <sstream>

#include <glm/glm.hpp>

struct Tetra {
	int a,b,c,d;
};
#pragma comment(lib, "glew32.lib")

using namespace std;

const int width = 1024, height = 1024;

const int PREINT_TEXSIZE=512;

int oldX=0, oldY=0;
float rX=15, rY=0;
int state =1 ;
float dist=-23;
const int GRID_SIZE=10;


LARGE_INTEGER frequency;        // ticks per second
LARGE_INTEGER t1, t2;           // ticks
double frameTimeQP=0;
float frameTime=0 ;

float startTime=0, currentTime=0, fps=0;
int totalFrames=0;

#include "GLSLShader.h"
GLSLShader shader;

char info[MAX_PATH]={0};

GLuint expoTexID;
int num_vertices, num_tetras;
#include <vector>
std::vector<glm::vec4> vertices;
std::vector<Tetra> tetras;
float max_distance = 0.025f;
float reciprocal_of_optical_distance = 1/max_distance;

GLfloat tf[256][4];
float maxScalar=-1000;

#include <algorithm>
int comp(const Tetra tA, const Tetra tB) {
	glm::vec4 va1 = vertices[tA.a];
	glm::vec4 vb1 = vertices[tA.b];
	glm::vec4 vc1 = vertices[tA.c];
	glm::vec4 vd1 = vertices[tA.d];

	glm::vec4 va2 = vertices[tB.a];
	glm::vec4 vb2 = vertices[tB.b];
	glm::vec4 vc2 = vertices[tB.c];
	glm::vec4 vd2 = vertices[tB.d];

	glm::vec4 cA = (va1+vb1+vc1+vd1)*0.25f;
	glm::vec4 cB = (va2+vb2+vc2+vd2)*0.25f;
	float lenA2 = glm::dot(cA, cA);
	float lenB2 = glm::dot(cB, cB);

	return lenA2<lenB2; 
}

void OnMouseDown(int button, int s, int x, int y) {
	if (s == GLUT_DOWN) {
		oldX = x;
		oldY = y; 
	}

	if(button == GLUT_MIDDLE_BUTTON)
		state = 0;
	else
		state = 1;

	if(s==GLUT_UP) {
		glutSetCursor(GLUT_CURSOR_INHERIT);
	}
}

void OnMouseMove(int x, int y) {
	if (state == 0)
		dist *= (1 + (y - oldY)/60.0f);
	else {
		rY += (x - oldX)/5.0f;
		rX += (y - oldY)/5.0f;
	}
	oldX = x;
	oldY = y;
	glutPostRedisplay();
}


void DrawGrid()
{
	glBegin(GL_LINES);
	glColor3f(0.5f, 0.5f, 0.5f);
	for(int i=-GRID_SIZE;i<=GRID_SIZE;i++)
	{
		glVertex3f((float)i,0,(float)-GRID_SIZE);
		glVertex3f((float)i,0,(float)GRID_SIZE);

		glVertex3f((float)-GRID_SIZE,0,(float)i);
		glVertex3f((float)GRID_SIZE,0,(float)i);
	}
	glEnd();
}

void InitGL() {
	shader.LoadFromFile(GL_VERTEX_SHADER, "shaders/shader.vert");
	shader.LoadFromFile(GL_FRAGMENT_SHADER, "shaders/shader.frag");
	shader.CreateAndLinkProgram();
	shader.Use();
		shader.AddAttribute("v0");
		shader.AddAttribute("v1");
		shader.AddAttribute("v2");
		shader.AddAttribute("v3"); 
		shader.AddAttribute("c0");
		shader.AddAttribute("c1");
		shader.AddAttribute("c2");
		shader.AddAttribute("c3");
	shader.UnUse();

	startTime = (float)glutGet(GLUT_ELAPSED_TIME);
	currentTime = startTime; 

	QueryPerformanceFrequency(&frequency); 
	QueryPerformanceCounter(&t1); 
	 
  /*
	GLfloat light_ambient[] = {  .2f, .2f, .2f, 1.0f };
	GLfloat light_diffuse[] = {  .7f, .7f, .7f, 1.0f };
	GLfloat light_specular[] = { 1.f, 1.f, 1.f, 1.0f };
	GLfloat spec[] = {1, 1, 1, 1};
	GLfloat color[] = {1, 1, 1, 1};
	GLfloat light0[] = {1, 1, 1, 0};
	GLfloat shine[] = {128.0f};
	glMaterialfv(GL_FRONT_AND_BACK, GL_AMBIENT_AND_DIFFUSE, color);
	glMaterialfv(GL_FRONT_AND_BACK, GL_SPECULAR, spec);
	glMaterialfv(GL_FRONT_AND_BACK, GL_SHININESS, shine);
	glLightfv(GL_LIGHT0, GL_AMBIENT, light_ambient);
	glLightfv(GL_LIGHT0, GL_DIFFUSE, light_diffuse);
	glLightfv(GL_LIGHT0, GL_SPECULAR, light_specular);
	glLightfv(GL_LIGHT0, GL_POSITION, light0);
	glEnable(GL_LIGHT0);
*/
	// Set up openGL parameters
	glShadeModel(GL_SMOOTH);
	glDisable(GL_POLYGON_SMOOTH);
	glEnable(GL_BLEND);
	//glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
	glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);

	glDisable(GL_DEPTH_TEST);
	glPolygonMode(GL_FRONT, GL_FILL);
	//glPolygonMode(GL_BACK, GL_LINE);
	//glPolygonMode(GL_FRONT_AND_BACK, GL_LINE);
	glDisable(GL_CULL_FACE);
	
	/*
	// Texture
	glGenTextures(1, &expoTexID);
	glActiveTexture(GL_TEXTURE0);
	glBindTexture(GL_TEXTURE_2D, expoTexID);

	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
	glTexEnvf(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_MODULATE);

	GLfloat* expo_tex=new GLfloat[4096*4096];
	int i=0, j=0;
	// Exponential texture
	for (i=0;i<PREINT_TEXSIZE;i++)
		for (j=0;j<PREINT_TEXSIZE;j++)
			expo_tex[i*PREINT_TEXSIZE+j] = 1.0f - exp((-(float)i/256.0f)*((float)j/256.0f));
	
	glTexImage2D(GL_TEXTURE_2D, 0, GL_ALPHA, PREINT_TEXSIZE,PREINT_TEXSIZE, 0, GL_ALPHA, GL_FLOAT, expo_tex);	
	delete [] expo_tex;
*/
	std::ifstream infile("datasets/spx.off", std::ios_base::in);
	std::string line;
	std::getline(infile, line, '\n');
	stringstream s(line);
	s>>num_vertices>>num_tetras;

	 
	//read all vertices
	for(int i=0;i<num_vertices;i++) {
		std::getline(infile,line,'\n');
		stringstream s2(line);
		glm::vec4 v;
		s2>>v.x>>v.y>>v.z>>v.w;
		maxScalar = max(maxScalar, v.w);
		vertices.push_back(v);
	}
	
	//read all tetrahedra
	for(int i=0;i<num_tetras;i++) {
		std::getline(infile,line,'\n');
		stringstream s2(line);
		Tetra t;
		s2>>t.a>>t.b>>t.c>>t.d; 
		tetras.push_back(t);
	}
	
	infile.close();	

	infile.open("datasets/spx.tf");
	int total = 0;
	infile>>total;
	for(int i=0;i<total;i++) {
		infile>>tf[i][0]>>tf[i][1]>>tf[i][2]>>tf[i][3];
	}
	infile.close();
}

void OnReshape(int nw, int nh) {
	glViewport(0,0,nw, nh);
	glMatrixMode(GL_PROJECTION);
	glLoadIdentity();
	gluPerspective(60, (GLfloat)nw / (GLfloat)nh, 1.f, 100.0f);
	
	glMatrixMode(GL_MODELVIEW);
}

void OnRender() {
	size_t i=0;
	float newTime = (float) glutGet(GLUT_ELAPSED_TIME);
	frameTime = newTime-currentTime;
	currentTime = newTime;
	//accumulator += frameTime;

	//Using high res. counter
	QueryPerformanceCounter(&t2);
	// compute and print the elapsed time in millisec
	frameTimeQP = (t2.QuadPart - t1.QuadPart) * 1000.0 / frequency.QuadPart;
	t1=t2;
	 
	++totalFrames;
	if((newTime-startTime)>1000)
	{
		float elapsedTime = (newTime-startTime);
		fps = (totalFrames/ elapsedTime)*1000 ;
		startTime = newTime;
		totalFrames=0;
	}

	sprintf_s(info, "FPS: %3.2f, Frame time (GLUT): %3.4f msecs, Frame time (QP): %3.3f", fps, frameTime, frameTimeQP);
	glutSetWindowTitle(info);
	glClear(GL_COLOR_BUFFER_BIT| GL_DEPTH_BUFFER_BIT);
	glLoadIdentity(); 
	
	glTranslatef(0,0,dist);
	glRotatef(rX,1,0,0);
	glRotatef(rY,0,1,0);
	 
	//draw grid
	DrawGrid(); 
		
	//sort tetrahedra
	std::sort(tetras.begin(), tetras.end(), comp);

	glEnable(GL_BLEND);
	shader.Use(); 
	for(int i=0;i<num_tetras;i++) {
		glm::vec4 v0 = vertices[tetras[i].a];
		glm::vec4 v1 = vertices[tetras[i].b];
		glm::vec4 v2 = vertices[tetras[i].c];
		glm::vec4 v3 = vertices[tetras[i].d];
		float t0 = v0.w;
		float t1 = v1.w;
		float t2 = v2.w;
		float t3 = v3.w;

		int s0 = int((v0.w/maxScalar)*255); v0.w = 1;
		int s1 = int((v1.w/maxScalar)*255); v1.w = 1;
		int s2 = int((v2.w/maxScalar)*255); v2.w = 1;
		int s3 = int((v3.w/maxScalar)*255); v3.w = 1;
		glVertexAttrib4fv(shader["v0"], &v0.x);
		glVertexAttrib4fv(shader["v1"], &v1.x);
		glVertexAttrib4fv(shader["v2"], &v2.x);
		glVertexAttrib4fv(shader["v3"], &v3.x);		 
		
		glVertexAttrib4f(shader["c0"], tf[s0][0],tf[s0][1],tf[s0][2],t0);
		glVertexAttrib4f(shader["c1"], tf[s1][0],tf[s1][1],tf[s1][2],t1);
		glVertexAttrib4f(shader["c2"], tf[s2][0],tf[s2][1],tf[s2][2],t2);
		glVertexAttrib4f(shader["c3"], tf[s3][0],tf[s3][1],tf[s3][2],t3);

		glBegin(GL_TRIANGLE_FAN);
			glVertex3f( 0, 1, 0);
			glVertex3f( 1, 0, 1);
			glVertex3f( 2, 0, 1);
			glVertex3f( 3, 0, 1);
			glVertex3f( 4, 0, 1);
			glVertex3f( 1, 0, 1);	 		
		glEnd();
	}
	shader.UnUse();
	glDisable(GL_BLEND);
	/*
	//debug draw the .off mesh
	glBegin(GL_TRIANGLES);
		glColor3f(0,1,0);
		for(int i=0;i<num_tetras;i++) { 
			glVertex3fv(&vertices[tetras[i].a].x);
			glVertex3fv(&vertices[tetras[i].b].x);
			glVertex3fv(&vertices[tetras[i].c].x);

			glVertex3fv(&vertices[tetras[i].a].x);
			glVertex3fv(&vertices[tetras[i].c].x);
			glVertex3fv(&vertices[tetras[i].d].x);

			glVertex3fv(&vertices[tetras[i].a].x);
			glVertex3fv(&vertices[tetras[i].d].x);
			glVertex3fv(&vertices[tetras[i].b].x);

			glVertex3fv(&vertices[tetras[i].b].x);
			glVertex3fv(&vertices[tetras[i].c].x);
			glVertex3fv(&vertices[tetras[i].d].x);
		}
	glEnd();
	*/
	glutSwapBuffers();
}

void OnShutdown() {
	// glDeleteTextures(1, &expoTexID);
}
 

 
void OnIdle() { 
	glutPostRedisplay();
} 

void main(int argc, char** argv) {

	glutInit(&argc, argv);
	glutInitDisplayMode(GLUT_DOUBLE | GLUT_RGBA | GLUT_DEPTH);
	glutInitWindowSize(width, height);
	glutCreateWindow("simple Gator implementation");

	glewInit();

	glutDisplayFunc(OnRender);
	glutReshapeFunc(OnReshape);
	glutIdleFunc(OnIdle);

	glutMouseFunc(OnMouseDown);
	glutMotionFunc(OnMouseMove);

	glutCloseFunc(OnShutdown);

	glewInit();
	InitGL();

	glutMainLoop();
}
