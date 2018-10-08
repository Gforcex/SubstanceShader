using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using System;
using System.IO;
public class Prefilter
{
    float[,] coeffs = new float[9, 3];                  /* Spherical harmonic coefficients */
    Matrix4x4[] matrix = new Matrix4x4[3];              /* Matrix for quadratic form */

    public void PrefilterEnvMap(Texture2D tex)
    {
        int width = tex.width;
        int height = tex.height;
        Color[,] hdr = new Color[height, width];     
        for (int i = 0; i < height; i++)
            for (int j = 0; j < width; j++)
            {
                hdr[i,j] = GammaToLinearSpace( tex.GetPixel(i, j) );
            }
        //don't handle environment_rotation, yet!
        prefilter(hdr, width, height);
        tomatrix();
    }

    public Matrix4x4 GetMatrix(int i)
    {
        if (i >= 3) return default(Matrix4x4);
        return matrix[i];
    }

    float sinc(float x)
    {    
        /* Supporting sinc function */
        if (Mathf.Abs(x) < 1.0e-4) return 1.0f;
        else return (Mathf.Sin(x) / x);
    }

    Color GammaToLinearSpace(Color col)
    {
        return col;

        return new Color(
            Mathf.GammaToLinearSpace(col.r),
            Mathf.GammaToLinearSpace(col.g),
            Mathf.GammaToLinearSpace(col.b),
            col.a
            );
    }

    void updatecoeffs(Color hdr, float domega, float x, float y, float z)
    {

        /****************************************************************** 
         Update the coefficients (i.e. compute the next term in the
         integral) based on the lighting value hdr[3], the differential
         solid angle domega and cartesian components of surface normal x,y,z

         Inputs:  hdr = L(x,y,z) [note that x^2+y^2+z^2 = 1]
                  i.e. the illumination at position (x,y,z)

                  domega = The solid angle at the pixel corresponding to 
              (x,y,z).  For these light probes, this is given by 

              x,y,z  = Cartesian components of surface normal

         Notes:   Of course, there are better numerical methods to do
                  integration, but this naive approach is sufficient for our
              purpose.

        *********************************************************************/

        for (int col = 0; col < 3; col++)
        {
            float c; /* A different constant for each coefficient */

            /* L_{00}.  Note that Y_{00} = 0.282095 */
            c = 0.282095f;
            coeffs[0,col] += hdr[col] * c * domega;

            /* L_{1m}. -1 <= m <= 1.  The linear terms */
            c = 0.488603f;
            coeffs[1,col] += hdr[col] * (c * y) * domega;   /* Y_{1-1} = 0.488603 y  */
            coeffs[2,col] += hdr[col] * (c * z) * domega;   /* Y_{10}  = 0.488603 z  */
            coeffs[3,col] += hdr[col] * (c * x) * domega;   /* Y_{11}  = 0.488603 x  */

            /* The Quadratic terms, L_{2m} -2 <= m <= 2 */

            /* First, L_{2-2}, L_{2-1}, L_{21} corresponding to xy,yz,xz */
            c = 1.092548f;
            coeffs[4,col] += hdr[col] * (c * x * y) * domega; /* Y_{2-2} = 1.092548 xy */
            coeffs[5,col] += hdr[col] * (c * y * z) * domega; /* Y_{2-1} = 1.092548 yz */
            coeffs[7,col] += hdr[col] * (c * x * z) * domega; /* Y_{21}  = 1.092548 xz */

            /* L_{20}.  Note that Y_{20} = 0.315392 (3z^2 - 1) */
            c = 0.315392f;
            coeffs[6,col] += hdr[col] * (c * (3 * z * z - 1)) * domega;

            /* L_{22}.  Note that Y_{22} = 0.546274 (x^2 - y^2) */
            c = 0.546274f;
            coeffs[8,col] += hdr[col] * (c * (x * x - y * y)) * domega;
        }
    }

    public void PrefilterCube(Cubemap cube)
    {
        ulong faceSize = (ulong)cube.width;
        float[] dc = new float[9];
        Vector3 u = Vector3.zero;

        for (ulong face = 0; face < 6; ++face)
        {
            Color rgba = Color.black;
            Color[] pixels = cube.GetPixels((CubemapFace)face, 0);
            for (ulong y = 0; y < faceSize; ++y)
                for (ulong x = 0; x < faceSize; ++x)
                {
                    //compute cube direction
                    float areaweight = 1f;
                    CubeUtil.invCubeLookup(ref u, ref areaweight, face, x, y, faceSize);
                    ulong index = y * faceSize + x;
                    rgba = GammaToLinearSpace(pixels[index]);
                    //areaweight *= 4f / 3f;
                    updatecoeffs(rgba, areaweight, u.x, u.y, u.z);
                }
        }
    }

    void prefilter(Color[,] hdr, int width, int height)
    {
        /* The main integration routine.  Of course, there are better ways
           to do quadrature but this suffices.  Calls updatecoeffs to
           actually increment the integral. Width is the size of the
           environment map */

        for (int i = 0; i < height; i++)
            for (int j = 0; j < width; j++)
            {
                /* We now find the cartesian components for the point (i,j) */
                float u, v, r, theta, phi, x, y, z, domega;

                v = (height / 2.0f - i) / (height / 2.0f);    /* v ranges from -1 to 1 */
                u = (j - width / 2.0f) / (width / 2.0f);    /* u ranges from -1 to 1 */
                r = Mathf.Sqrt(u * u + v * v);              /* The "radius" */
                if (r > 1.0) continue;              /* Consider only circle with r<1 */

                theta = Mathf.PI * r;                    /* theta parameter of (i,j) */
                phi = Mathf.Atan2(v, u);                 /* phi parameter */

                x = Mathf.Sin(theta) * Mathf.Cos(phi);         /* Cartesian components */
                y = Mathf.Sin(theta) * Mathf.Sin(phi);
                z = Mathf.Cos(theta);

                /* Computation of the solid angle.  This follows from some
               elementary calculus converting sin(theta) d theta d phi into
               coordinates in terms of r.  This calculation should be redone 
               if the form of the input changes */

                domega = (2 * Mathf.PI / height) * (2 * Mathf.PI / width) * sinc(theta);

                updatecoeffs(hdr[i,j], domega, x, y, z); /* Update Integration */

            }
    }

    void tomatrix()
    {
        /* Form the quadratic form matrix (see equations 11 and 12 in paper) */
        float c1, c2, c3, c4, c5;
        c1 = 0.429043f; c2 = 0.511664f;
        c3 = 0.743125f; c4 = 0.886227f; c5 = 0.247708f;

        for (int col = 0; col < 3; col++)
        {
            /* Equation 12 */
            matrix[col][0,0] = c1 * coeffs[8,col]; /* c1 L_{22}  */
            matrix[col][0,1] = c1 * coeffs[4,col]; /* c1 L_{2-2} */
            matrix[col][0,2] = c1 * coeffs[7,col]; /* c1 L_{21}  */
            matrix[col][0,3] = c2 * coeffs[3,col]; /* c2 L_{11}  */

            matrix[col][1,0] = c1 *  coeffs[4,col]; /* c1 L_{2-2} */
            matrix[col][1,1] = -c1 * coeffs[8,col]; /*-c1 L_{22}  */
            matrix[col][1,2] = c1 *  coeffs[5,col]; /* c1 L_{2-1} */
            matrix[col][1,3] = c2 *  coeffs[1,col]; /* c2 L_{1-1} */

            matrix[col][2,0] = c1 * coeffs[7,col]; /* c1 L_{21}  */
            matrix[col][2,1] = c1 * coeffs[5,col]; /* c1 L_{2-1} */
            matrix[col][2,2] = c3 * coeffs[6,col]; /* c3 L_{20}  */
            matrix[col][2,3] = c2 * coeffs[2,col]; /* c2 L_{10}  */

            matrix[col][3,0] = c2 * coeffs[3,col]; /* c2 L_{11}  */
            matrix[col][3,1] = c2 * coeffs[1,col]; /* c2 L_{1-1} */
            matrix[col][3,2] = c2 * coeffs[2,col]; /* c2 L_{10}  */
            matrix[col][3,3] = c4 * coeffs[0,col] - c5 * coeffs[6,col];
            /* c4 L_{00} - c5 L_{20} */
        }
    }
}
