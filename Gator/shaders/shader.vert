//ripped from http://www.sandia.gov/~kmorel/documents/gator/gator.cg

attribute vec4 v0;
attribute vec4 v1;
attribute vec4 v2;
attribute vec4 v3; 
attribute vec4 c0;
attribute vec4 c1;
attribute vec4 c2;
attribute vec4 c3;

varying vec4 color; 

struct tetra {
	vec4 vselect;
	vec4 v0;
	vec4 v1;
	vec4 v2;
	vec4 v3;
	vec4 c0;
	vec4 c1;
	vec4 c2;
	vec4 c3;
};
struct rayseg {
    vec4 position;
    vec2 depth_tau;
    vec4 color;
};
 

const vec4 texture_mask = { 1.0, 0.0, 0.0, 1.0};
const float zero = 0.0;
const float one = 1.0;


const vec4 MappingTable[32] = vec4[32]( 
    vec4( 1, 0, 0, 0 ),	/* 4 masks for each of the 8 cases*/
    vec4( 0, 0, 0, 1 ),	/*     (0, 3, 1, 2)*/
    vec4( 0, 1, 0, 0 ),
    vec4( 0, 0, 1, 0 ),

    vec4( 1, 0, 0, 0 ),	/*     (0, 3, 2, 1)*/
    vec4( 0, 0, 0, 1 ),
    vec4( 0, 0, 1, 0 ),
    vec4( 0, 1, 0, 0 ),

    vec4( 1, 0, 0, 0 ),	/*     (0, 2, 1, 3)*/
    vec4( 0, 0, 1, 0 ),
    vec4( 0, 1, 0, 0 ),
    vec4( 0, 0, 0, 1 ),

    vec4( 1, 0, 0, 0 ),	/*     (0, 2, 3, 1)*/
    vec4( 0, 0, 1, 0 ),
    vec4( 0, 0, 0, 1 ),
    vec4( 0, 1, 0, 0 ),

    vec4( 1, 0, 0, 0 ),	/*     (0, 1, 3, 2)*/
    vec4( 0, 1, 0, 0 ),
    vec4( 0, 0, 0, 1 ),
    vec4( 0, 0, 1, 0 ),

    vec4( 1, 0, 0, 0 ),	/*     (0, 1, 2, 3)*/
    vec4( 0, 1, 0, 0 ),
    vec4( 0, 0, 1, 0 ),
    vec4( 0, 0, 0, 1 ),

    vec4( 0, 0, 1, 0 ),	/*     (2, 0, 3, 1)*/
   vec4 ( 1, 0, 0, 0 ),
   vec4 ( 0, 0, 0, 1 ),
    vec4( 0, 1, 0, 0 ),

    vec4( 0, 0, 0, 1 ),	/*     (3, 0, 2, 1)*/
    vec4( 1, 0, 0, 0 ),
    vec4( 0, 0, 1, 0 ),
    vec4( 0, 1, 0, 0 )
);
/* See final_multiplex() for more details. */
const vec4 RunSelectTable[20] = vec4[20](
    vec4( 0, 1, 0, 0 ),	/* run 0, !t4: output vertex 1*/
    vec4( 0, 0, 0, 0 ),
    vec4( 0, 0, 0, 0 ),	/* run 0, t4: output interpolated vertex*/
    vec4( 1, 0, 0, 0 ),
    vec4( 0, 0, 1, 0 ),	/* run 1: output vertex 2*/
    vec4( 0, 0, 0, 0 ),
    vec4( 0, 0, 1, 0 ),	/* ditto*/
    vec4( 0, 0, 0, 0 ),
    vec4( 1, 0, 0, 0 ),	/* run 2: output vertex 0*/
    vec4( 0, 0, 0, 0 ),
    vec4( 1, 0, 0, 0 ),	/* ditto*/
    vec4( 0, 0, 0, 0 ),
    vec4( 0, 0, 0, 1 ),	/* run 3: output vertex 3*/
    vec4( 0, 0, 0, 0 ),
    vec4( 0, 0, 0, 1 ),	/* ditto*/
    vec4( 0, 0, 0, 0 ),
    vec4( 0, 0, 1, 0 ),	/* run 4, !t4: output vertex 2*/
    vec4( 0, 0, 0, 0 ),
    vec4( 0, 1, 0, 0 ),	/* run 4, t4: output vertex 1*/
    vec4( 0, 0, 0, 0 )
);

 




/* Output color still needs to be blended with the color already in the
 * frame buffer.  Use
 *
 *	glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA).
 *
 * and don't forget to enable GL_BLEND.  While this will not compile with
 * NV20 register combiner profiles, you can easily change it to use texture
 * lookups to perform the exp function. */
vec4 IntegrateRaySegment(  rayseg input)
{
    vec4 color;
    float alpha;
    alpha = 1.0 - exp(-input.depth_tau.x*input.depth_tau.y);
    color.rgb = input.color.rgb*alpha;
    color.a = alpha;
    return color;
}

/* Returns the Z value of the cross product. */
float zcross(in vec3 vec0, in vec3 vec1)
{
    vec2 tmp = vec0.xy * vec1.yx;
    return tmp.x - tmp.y;
}

/*
 * Perform tests 1, 2, and 3.
 * Return vector: (t1, t2, t3, -)
 *
 * t1 : v1 "between" v2 and v3
 * t2 : v2 "between" v1 and v3
 * t3 : v2 counter-clockwise from v1
 *
 * vA between vB and vC means vAv0 splits the angle vBv0vC that is less
 * than 180 degrees.
 */
bool4 tests123(in vec4 v0, in vec4 v1, in vec4 v2, in vec4 v3)
{
    bool4 tests;

    vec3 va = (v1 - v0).xyz;
    vec3 vb = (v2 - v0).xyz;
    vec3 vc = (v3 - v0).xyz;

    vec2 tmp;

    vec3 zcrosses;

    zcrosses.x = zcross(va, vb);
    zcrosses.y = zcross(va, vc);
    zcrosses.z = zcross(vc, vb);

    //tests.xy = (zcrosses.xx * zcrosses.yz) < vec2(0,0);
    tests.x = (zcrosses.x * zcrosses.y) < 0;
    tests.y = (zcrosses.x * zcrosses.z) < 0;
    tests.z = zcrosses.x > 0;

    return tests;
}

/*
 * If flag is 0, 1, 2, or 3, returns the corresponding input value.
 */
vec4 multiplex(vec4 mask,
		 in vec4 x0, in vec4 x1, in vec4 x2, in vec4 x3)
{
    vec4 result;

    result = (float)mask.x * x0;
    result = (float)mask.y * x1 + result;
    result = (float)mask.z * x2 + result;
    result = (float)mask.w * x3 + result;

    return result;
}

/*
 * Maps vertices based on the table.  The table is indexed by the
 * boolean values in tests as: 4*tests.x + 2*tests.y + tests.z.
 */
void mapvertices(bool4 tests,
		 in vec4 v0in, in vec4 v1in,
		 in vec4 v2in, in vec4 v3in,
		 out vec4 v0out, out vec4 v1out,
		 out vec4 v2out, out vec4 v3out,
		 in vec4 c0in, in vec4 c1in,
		 in vec4 c2in, in vec4 c3in,
		 out vec4 c0out, out vec4 c1out,
		 out vec4 c2out, out vec4 c3out)
{
    float index;

    index = 4*((float)tests.z + (float)tests.y * 2 + (float)tests.x * 4);

    v0out = multiplex(MappingTable[index  ], v0in, v1in, v2in, v3in);
    v1out = multiplex(MappingTable[index+1], v0in, v1in, v2in, v3in);
    v2out = multiplex(MappingTable[index+2], v0in, v1in, v2in, v3in);
    v3out = multiplex(MappingTable[index+3], v0in, v1in, v2in, v3in);

    c0out = multiplex(MappingTable[index  ], c0in, c1in, c2in, c3in);
    c1out = multiplex(MappingTable[index+1], c0in, c1in, c2in, c3in);
    c2out = multiplex(MappingTable[index+2], c0in, c1in, c2in, c3in);
    c3out = multiplex(MappingTable[index+3], c0in, c1in, c2in, c3in);

    return;
}

/*
 * Computes the intersection of the projections of v0v1 and v2v3 on the X-Y
 * plane.  i1 is the intersection along v0v1 and i2 is the intersection
 * along v2v3.  i1 and i2 should (theoretically) only differ by Z
 * coordinate.  interp.x = dist(v0,i1)/dist(v0,v1).  Likewise,
 * interp.y = dist(v2,i2)/dist(v2,v3).
 */
void compute_intersection(in vec4 v0, in vec4 v1,
			  in vec4 v2, in vec4 v3,
			  out vec4 interp,
			  out vec4 i1, out vec4 i2)
{
    float denominator;
    vec4 A, B, C;

  /*
   * This algorithm is based of that given in Graphics Gems III,
   * pg. 199-202.  We find the intersection by linearly interpolating
   * between the points.  First, we define the two equations.
   *
   *	v0 + alpha(v1 - v0)
   *	v2 + beta(v3 - v2)
   *
   * and then find the A and B with which the two equations are equal for
   * both x and y values.  Subtracting these two equations, we get:
   *
   *	0 = (v0 - v2) + alpha(v1 - v0) - beta(v3 - v2)
   */
    A = v1 - v0;
    B = v3 - v2;
    C = v0 - v2;

  /*
   * Now our equation is:
   *
   *	0 = C + alpha*A - beta*B
   *
   * By looking separately at the equations for x and y coordinates (and
   * ignoring z) we find that alpha and beta are:
   *
   *	alpha = (B.x*C.y - B.y*C.x)/(A.x*B.y - A.y*B.x)
   *	beta  = (A.x*C.y - A.y*C.x)/(A.x*B.y - A.y*B.x)
   *
   * Note that the denominators are the same.
   */
    interp.x = B.x*C.y - B.y*C.x;
    interp.y = A.x*C.y - A.y*C.x;

    denominator = 1.0/(A.x*B.y - A.y*B.x);

    interp.xy = interp.xy * denominator;

  /* Now get the intersection point coordinates:
   *
   *	I = v0 + alpha*(v1 - v0) = v0 + interp.x*A
   *
   * or
   *
   *	I = v2 + beta*(v3 - v2) = v2 + interp.y*B
   *
   * i1 and i2 should be the same except for their z coordinates.
   */
    i1 = v0 + interp.x*A;
    i2 = v2 + interp.y*B;

    return;
}

/*
 * Computes the thickness at the current vertex (selected by vselect).
 */
float compute_depth(in vec4 interp, in vec4 i1, in vec4 i2,
		    in bool test4, in float vselect)
{
    float depth_i;
    float depth_v1;
    float depth;

  /* Find the depth at the intersection point. */
    depth_i = abs(i1.z - i2.z);

  /* If test4 is true, then the intersection point is where the depth
   * value is calculated.  If it is false, the depth should be calculated at
   * v1.  In this case, we can get the depth by simply interpolating back
   * from the intersection point.  We reuse the interpolation value
   * calculated in the depth test for this. */
    depth_v1 = depth_i/interp.x;

  /* Pick the correct value based on test4. */
    depth = test4 ? depth_i : depth_v1;

  /* We really only have a thickness when selecting vertex 0, otherwise
   * zero it out. */
    depth = depth * (float)(vselect < 1);

    return depth;
}

/*
 * Multiplex the final vertex output.  Assumes that vertices are arranged
 * as:
 *
 *     v0--                             v0-----v2                 
 *      |\ --			                 |\   /|                  
 *      | \  --			                 | \ / |                  
 *      | v1---v2 if test4 is false or   |  i1 |  if test4 is true
 *      | /  --			                 | / \ |                  
 *      |/ --			                 |/   \|                  
 *     v3--			                    v3-----v1                 
 *
 * To make a proper triangle fan (possibly with degenerate triangles) we
 * output the vertices in the order
 *
 *	v1, v2, v0, v3, v2, v2 if test4 is false.
 *	i1, v2, v0, v3, v1, v2 if test4 is true or
 *
 * Because the second and sixth vertex is the same in both cases, vertices
 * are selected in the order 0, 1, 2, 3, 4, 1 in order to make a proper
 * triangle fan (possibly with degenerate triangles).  The output table is
 * therefore:
 *
 *    vselect test4 output
 *       0      0     v1
 *       0      1     i1
 *       1      -     v2
 *       2      -     v0
 *       3      -     v3
 *       4      0     v2
 *       4      1     v1
 *
 * This table is implemented with a RunSelectTable defined above.
 */
void final_multiplex(in float vselect, in bool test4,
		     in vec4 v0, in vec4 v1, in vec4 v2, in vec4 v3,
		     in vec4 i1, in vec4 i2,
		     in vec4 c0, in vec4 c1, in vec4 c2, in vec4 c3,
		     in vec4 interp,
		     out vec4 position, out vec3 color, out float tau)
{
    float index;
    vec4 ic1, ic2;
    vec4 avg_color;
    vec4 tmp;

    index = 4*vselect + 2*(float)test4;
    position = multiplex(RunSelectTable[index], v0, v1, v2, v3);
    position = RunSelectTable[index+1].x*i1 + position;

  /*
    Find color of lines at intersections. 
    If test4 is false, v1 is in middle of tet.  Therefore, colors on
    intersection not really correct.  ic1 color should be color at v1 and
    ic2 color needs to be interpolated back to v0 (see figure above). 
    */
    ic1 = test4 ? (c0 + interp.x*(c1-c0)) : c1;
    tmp = (c2 + interp.y*(c3-c2));
    ic2 = test4 ? tmp : (c0 + (tmp-c0)/interp.x);

    avg_color = vselect ?
	multiplex(RunSelectTable[index], c0, c1, c2, c3) : 0.5*(ic1+ic2);

    color = avg_color.xyz;
    tau = avg_color.w;
}

  rayseg ProjectTetrahedron(  tetra tetrahedron)
{
    rayseg output;

    vec4 v0, v1, v2, v3;
    vec4 c0, c1, c2, c3;
    bool4 tests;

    vec4 interp;
    vec4 i1, i2;

    vec4 color;

  // Transform to normalized screen coordinates. 
    v0 = tetrahedron.v0 ;
    v1 = tetrahedron.v1 ;
    v2 = tetrahedron.v2 ;
    v3 = tetrahedron.v3 ;

  // Perform first 3 tests. 
    tests = tests123(v0, v1, v2, v3);

  // With the MappingTable and tests defined above, will map vertices
  // such that their convex hull is v0, v3, v1, v2 in counter clockwise
  // order, or v0, v3, v2 if v1 is not on the hull.  
    mapvertices(tests, v0, v1, v2, v3, v0, v1, v2, v3,
		tetrahedron.c0, tetrahedron.c1, tetrahedron.c2, tetrahedron.c3,
		c0, c1, c2, c3);

    compute_intersection(v0, v1, v2, v3, interp, i1, i2);

  // Compute final test.  Test 4 is true iff all vertices are part of the
  // convex hull.  Based on the remapping of vertices above, either v1 is
  // inside the convex hull, or all vertices are outside of it.  If inside,
  // the intersection of v0v1 and v2v3 will actually lie outside of v0v1,
  // and interp.x will be greater than 1.  Otherwise, the intersection will
  // be in v0v1, and 0 < interp.x < 1.  
    tests.w = interp.x < 1;

  // Set the depth value.  
    output.depth_tau.x = compute_depth(interp, i1, i2, tests.w,
				       tetrahedron.vselect.x);
    output.position = tetrahedron.vselect;

//      output.depth.x = tetrahedron.transmission.x  
//  	compute_depth(interp, i1, i2, tests.w, tetrahedron.vselect.x);  
//      output.depth.yzw = texture_mask.yzw;  
//      output.color = tetrahedron.color;  

// Select the appropriate output coordinates.  
//  i1.z = 0.5*(i1.z + i2.z);  

    final_multiplex(tetrahedron.vselect.x, tests.w,v0, v1, v2, v3, i1, i2,c0, c1, c2, c3, interp, output.position, output.color.xyz, output.depth_tau.y);

    return output;
}

void main() {
	tetra t;
	t.vselect = gl_Vertex;
	t.v0 = v0;
	t.v1 = v1;
	t.v2 = v2;
	t.v3 = v3;
	t.c0 = c0;
	t.c1 = c1;
	t.c2 = c2;
	t.c3 = c3;
	
	rayseg r;
	r = ProjectTetrahedron(t);
	color = IntegrateRaySegment(r); 
	gl_Position = gl_ModelViewProjectionMatrix * vec4(r.position.xyz,1);
}