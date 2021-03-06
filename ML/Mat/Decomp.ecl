IMPORT * FROM $;
EXPORT Decomp := MODULE

// Back substitution algorithm for solving an upper-triangular system of linear 
// equations UX = B 
EXPORT b_sub(DATASET(Types.Element) U, DATASET(Types.Element) B) := FUNCTION
	n := Has(U).Dimension;
	unn := U(x=n, y=n);
	b_wo_n := B(x<>n);
	b_w_n := B(x=n);
	scaled_b_n := Scale(b_w_n, 1/unn[1].value);
	new_b := b_wo_n + scaled_b_n;
	loopBody(DATASET( Types.Element) ds, UNSIGNED4 c) := FUNCTION	
				k := n-c;
	      ukk := U(x=k, y=k);				
				xk_1 := Mul(SetDimension(U(x=k),n,n), SetDimension(ds(x>k),n,n));
				xk_2 := Sub(SetDimension(ds(x=k),n,n), SetDimension(xk_1(x=k),n,n));
				xk_3 := Scale(xk_2, 1/ukk[1].value);
				xk := Substitute(ds, xk_3);
		RETURN xk;
  END;

	RETURN LOOP(new_b, n-1, loopBody(ROWS(LEFT),COUNTER));
END;

// Forward substitution algorithm for solving a lower-triangular system of linear
// equations LX = B
EXPORT f_sub(DATASET(Types.Element) L, DATASET(Types.Element) B) := FUNCTION
	n := Has(L).Dimension;
	loopBody(DATASET( Types.Element) ds, UNSIGNED4 c) := FUNCTION
				k := c;
				lkk := L(x=k, y=k);
				xk_1 := Mul(SetDimension(L(x=k), n, n), SetDimension(ds(x<k), n,n));
				xk_2 := Sub(SetDimension(ds(x=k),n,n), SetDimension(xk_1(x=k),n,n));
				xk_3 := Scale(xk_2, 1/lkk[1].value);
				xk := Substitute(ds,xk_3);
				
		RETURN xk;
  END;
	RETURN LOOP(B, n, loopBody(ROWS(LEFT),COUNTER));
END;

/*
This function performs Cholesky matrix decomposition (http://en.wikipedia.org/wiki/Cholesky_decomposition).

Choleski triangle is a decomposition of a Hermitian, positive-definite matrix into the product of a 
lower triangular matrix and its conjugate transpose. When it is applicable, the Cholesky decomposition
is roughly twice as efficient as the LU decomposition.
*/
EXPORT DATASET(Types.Element) Cholesky(DATASET(Types.Element) matrix) := FUNCTION
	n := Has(matrix).Dimension;
	loopBody(DATASET( Types.Element) ds, UNSIGNED4 k) := FUNCTION
				akk := ds(x=k AND y=k);
				lkk := Each.Sqrt(akk);
				col_k := Scale(ds(y=k, x>k), 1/lkk[1].value);
				l_lt := Mul(col_k,Trans(col_k),2);
				sub_m := Sub(ds(y>k AND x>=y),l_lt);
								
	RETURN Substitute(ds, sub_m+col_k+lkk);
  END;

	RETURN LowerTriangle(LOOP(matrix, n, loopBody(ROWS(LEFT),COUNTER)));
END;

/*
This function performs LU matrix decomposition (http://en.wikipedia.org/wiki/LU_decomposition).

LU decomposition of a square matrix A writes a matrix A as the product of a lower triangular matrix L
and an upper triangular matrix U. This decomposition is used in numerical analysis to solve systems
of linear equations, calculate the determinant of a matrix, or calculate the inverse of an invertible
square matric.

This implementation is based on the Gaussian Elimination Algorithm
*/
EXPORT DATASET(Types.Element) LU(DATASET(Types.Element) matrix) := FUNCTION
	n := Has(matrix).Dimension;
	loopBody(DATASET( Types.Element) ds, UNSIGNED4 k) := FUNCTION
				akk := ds(x=k AND y=k);
				lk := ds(y=k, x>k);
				lk1 := Scale(lk, 1/akk[1].value);
				leave1 := ds(y<=k OR x<=k);		
				leave := Substitute(leave1,lk1);
				to_change := ds(x>k,y>k);

				a_k := JOIN(leave(y=k, x>k), leave(x=k, y>k), LEFT.y = RIGHT.x, 
						TRANSFORM(Types.Element, SELF.x := LEFT.x, SELF.y := RIGHT.y, SELF.value := LEFT.value*RIGHT.value));
				changed := Sub(SetDimension(to_change,n,n), SetDimension(a_k,n,n));;
								
	RETURN leave+changed;
  END;

// Function returns both L and U as a single matrix: The L component is assumed to have all its diagonal
// elements equal to 1 	
	RETURN LOOP(matrix, n-1, loopBody(ROWS(LEFT),COUNTER));
END;

Types.Element unitDiag(Types.Element elm) := TRANSFORM
  SELF.value := IF(elm.x=elm.y, 1, elm.value);
  SELF := elm;
END;
EXPORT LComp(DATASET(Types.Element) l_u) := PROJECT(LowerTriangle(l_u), unitDiag(LEFT));
EXPORT UComp(DATASET(Types.Element) l_u) := UpperTriangle(l_u);


/*
	In linear algebra, a QR decomposition of a matrix is a decomposition of a matrix A into a product
	A=QR of an orthonormal matrix Q (ie Q*Q' = I) and an upper triangular matrix R.

	This decomposition is often used to solve a system of linear equations Ax=b, and it is basis for 
	a particular eigenvalue problem
*/
SHARED qr_comp := ENUM ( Q = 1,  R = 2 );
EXPORT DATASET(Types.Element) QR(DATASET(Types.Element) matrix) := FUNCTION

	n := Has(matrix).Stats.XMax;
	loopBody(DATASET( Types.MUElement) ds, UNSIGNED4 k) := FUNCTION

		Q := MU.From(ds, qr_comp.Q);
		R := MU.from(ds, qr_comp.R);
		hModule := Householder(Vec.FromCol(R,k),k,n);	
		//hM := hModule.Reflection(hModule.HTA.Atkinson);	
		hM := hModule.Reflection();		
		R1 := Mu.To(Mul(hM,R), qr_comp.R);		
		Q1 := Mu.To(Mul(Q, hM), qr_comp.Q);

	RETURN R1+Q1;
  END;
	

	RETURN LOOP(Mu.To(matrix, qr_comp.R)+Mu.To(Identity(n), qr_comp.Q), n-1, loopBody(ROWS(LEFT),COUNTER));
END;

EXPORT QComp(DATASET(Types.Element) matrix) := MU.From(QR(matrix), qr_comp.Q);
EXPORT RComp(DATASET(Types.Element) matrix) := MU.From(QR(matrix), qr_comp.R);;


END;