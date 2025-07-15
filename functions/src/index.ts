

// functions/src/index.ts

import {onCall, HttpsError} from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import * as admin from "firebase-admin";
import * as functions from "firebase-functions/v1";
import { UserRecord } from "firebase-functions/v1/auth";
import {CohereClient, CohereError} from "cohere-ai";
import cosineSimilarity from "cosine-similarity";
import { GoogleGenerativeAI, GoogleGenerativeAIFetchError } from "@google/generative-ai";

admin.initializeApp();
const db = admin.firestore();

// Helper function for retrying API calls with exponential backoff
const retryableApiCall = async <T>(apiCall: () => Promise<T>, maxRetries = 3, initialDelay = 1000): Promise<T> => {
    for (let i = 0; i < maxRetries; i++) {
        try {
            return await apiCall();
        } catch (error) {
            const isGoogleErrorRetryable = error instanceof GoogleGenerativeAIFetchError &&
                                             typeof error.status === 'number' &&
                                             error.status >= 500;
            const isCohereErrorRetryable = error instanceof CohereError &&
                                           error.statusCode != undefined &&
                                           error.statusCode >= 500;

            if ((isGoogleErrorRetryable || isCohereErrorRetryable) && i < maxRetries - 1) {
                const delay = initialDelay * Math.pow(2, i);
                logger.warn(`API call failed with retryable error. Retrying in ${delay}ms... (Attempt ${i + 1}/${maxRetries})`, error);
                await new Promise(resolve => setTimeout(resolve, delay));
            } else {
                throw error;
            }
        }
    }
    throw new Error("API call failed after all retries.");
};

// Helper function to get embeddings from Cohere
const getEmbedding = async (text: string, cohere: CohereClient): Promise<number[]> => {
  if (!text || text.trim().length === 0) return [];

  const apiCall = () => cohere.embed({
    texts: [text],
    model: "embed-multilingual-v3.0",
    inputType: "search_document",
  });

  try {
    const response = await retryableApiCall(apiCall);
    if (Array.isArray(response.embeddings)) {
      return response.embeddings[0] ?? [];
    }
    logger.warn("Received a complex embedding type from Cohere, returning empty.");
    return [];
  } catch (error) {
    logger.error(`Error getting Cohere embedding for text: "${text}"`, error);
    return [];
  }
};


// Deployed Cloud Function to confirm/delete a summary card
export const confirmSummaryPoint = onCall(
    { region: "europe-west1" },
    async (request) => {
      logger.info("confirmSummaryPoint called.");
      const userId = request.auth?.uid;
      if (!userId) {
        throw new HttpsError("unauthenticated", "User must be authenticated to perform this action.");
      }
      
      const {cardId, editedText} = request.data;
      const userAction = request.data.action;
      if (!cardId || !userAction) throw new HttpsError("invalid-argument", "cardId and action are required.");

      const cardRef = db.collection("pending_summaries").doc(cardId);
      const userRef = db.collection("users").doc(userId);

      try {
        if (userAction === "delete") {
          await cardRef.delete();
          logger.info(`Card ${cardId} deleted by user ${userId}.`);
          return {status: "success", message: "Card deleted."};
        }
        if (userAction === "confirm") {
          const cardDoc = await cardRef.get();
          if (!cardDoc.exists || cardDoc.data()?.userId !== userId) throw new HttpsError("not-found", "Card not found or permission denied.");
          
          const cardData = cardDoc.data()!;
          if (cardData.type === "insightPoint") {
            const pointToConfirm = editedText || cardData.point;
            if (!pointToConfirm) throw new HttpsError("invalid-argument", "Point text is missing for insightPoint.");
            await userRef.set({profileSummary: admin.firestore.FieldValue.arrayUnion(pointToConfirm)}, {merge: true});
          } else if (cardData.type === "profileUpdate") {
            const actionData = cardData.action;
            if (!actionData || !actionData.field || actionData.value === undefined) throw new HttpsError("invalid-argument", "Profile update action data is malformed.");
            
            if (actionData.type === "update") {
              await userRef.set({[actionData.field]: actionData.value}, {merge: true});
            } else if (actionData.type === "add_to_list") {
              await userRef.set({[actionData.field]: admin.firestore.FieldValue.arrayUnion(actionData.value)}, {merge: true});
            }
          }
          await cardRef.delete();
          return {status: "success", message: "Card confirmed and processed."};
        } else {
          throw new HttpsError("invalid-argument", "Invalid action provided.");
        }
      } catch (error) {
        logger.error(`Error processing card ${cardId} for user ${userId}:`, error);
        throw new HttpsError("internal", "Could not process summary point action.");
      }
    }
);
 

//ربط أسماء الحقول التقنية المستخدمة في قاعدة البيانات  بأسمائها المقروءة والمفهومة للمستخدم باللغة العربية 
  const fieldLabels: { [key: string]: string } = {
      displayName: "الاسم",
      gender: "الجنس",
      occupation: "المهنة",
      relationshipStatus: "الحالة الاجتماعية",
      preferredInteractionTime: "وقت التفاعل المفضل",
      cognitivePatterns: "أنماط التفكير",
      importantRelationships: "العلاقات الهامة",
      lifeChallenges: "تحديات الحياة",
      hobbies: "الهوايات",
      ambitions: "الطموحات",
      growthAreas: "مجالات للتطور",
      takesMedication: "يتناول دواء",
      medicationName: "اسم الدواء",
      seesTherapist: "يراجع معالجًا نفسيًا",
      healthConditions: "حالات صحية",
      title: "عنوان الدردشة",
  };


  //مقارنة النسختين لاكتشاف أي فروقات أو معلومات جديدة تمت إضافتها
  function generateChangeSuggestions(originalProfile: any, reconciledProfile: any, userId: string): any[] {
      const suggestions: any[] = [];
      const timestamp = admin.firestore.FieldValue.serverTimestamp();

      for (const key in reconciledProfile) {
          if (!fieldLabels[key]) continue;

          const newValue = reconciledProfile[key];
          const oldValue = originalProfile[key];
          
          const oldValForComp = oldValue === undefined ? null : oldValue;
          const newValForComp = newValue === undefined ? null : newValue;

          if (JSON.stringify(newValForComp) === JSON.stringify(oldValForComp)) {
              continue;
          }

          if (Array.isArray(newValue)) {
              if (key === 'importantRelationships') {
                  const oldNames = new Set((oldValue || []).map((rel: any) => rel.name));
                  
                  for (const item of newValue) {
                      if (item && item.name && !oldNames.has(item.name)) {
                          const pointText = `اقتراح: إضافة **'${item.name}'** إلى **${fieldLabels[key]}**.`;
                          suggestions.push({ userId, point: pointText, type: "profileUpdate", action: { field: key, value: item, type: "add_to_list" }, status: "pending", createdAt: timestamp });
                      }
                  }
              } else {
                  const oldSet = new Set(oldValue || []);
                  for (const item of newValue) {
                      if (item && !oldSet.has(item)) { 
                          const pointText = `اقتراح: إضافة **'${item}'** إلى **${fieldLabels[key]}**.`;
                          suggestions.push({ userId, point: pointText, type: "profileUpdate", action: { field: key, value: item, type: "add_to_list" }, status: "pending", createdAt: timestamp });
                      }
                  }
              }
          } else {
              if (newValue !== null && newValue !== undefined) {
                  const pointText = `اقتراح: تحديث **${fieldLabels[key]}** إلى **'${newValue}'**.`;
                  suggestions.push({ userId, point: pointText, type: "profileUpdate", action: { field: key, value: newValue, type: "update" }, status: "pending", createdAt: timestamp });
              }
          }
      }
      return suggestions;
  }



// بناء ملف المستخدم  
export const buildUserProfileV2 = onCall(
  { region: "europe-west1", timeoutSeconds: 180, memory: "1GiB", secrets: ["GOOGLE_API_KEY"] },
  async (request) => {
    logger.info("buildUserProfileV2 (v1.2 with Self-Correction Fix) started.");

    if (!process.env.GOOGLE_API_KEY) throw new HttpsError("internal", "GOOGLE_API_KEY is not configured.");
    const genAI = new GoogleGenerativeAI(process.env.GOOGLE_API_KEY);
    const model = genAI.getGenerativeModel({ model: "gemini-2.5-flash", generationConfig: { responseMimeType: "application/json" } });
    if (!request.auth || !request.auth.uid) throw new HttpsError("unauthenticated", "User not authenticated.");
    const userId = request.auth.uid;
    const sessionId = request.data.sessionId;
    if (!sessionId) throw new HttpsError("invalid-argument", "A 'sessionId' is required.");

    try {
        const messagesSnapshot = await db.collection("chat_messages").where("sessionId", "==", sessionId).where("userId", "==", userId).orderBy("timestamp", "asc").get();
        if (messagesSnapshot.empty) return { status: "success", message: "No messages to process." };
        const conversationText = messagesSnapshot.docs.map((doc) => `${doc.data().isFromUser ? "User" : "Fadfada"}: ${doc.data().content}`).join("\n");
        
        const observerPrompt = `
# دورك الأساسي
أنت محلل تحقيقات وخبير لغوي. مهمتك هي قراءة المحادثة التالية بدقة متناهية وإنتاج قائمة منظمة بـ "الاستنتاجات" (findings) المهمة. الاستنتاج يمكن أن يكون إما "حقيقة مباشرة" أو "ملاحظة ضمنية".
# تعريف أنواع الاستنتاجات
1.  **حقيقة مباشرة (Fact):** هي أي معلومة صرّح بها المستخدم بشكل مباشر وواضح.
    * أمثلة: "أعمل كمصمم"، "أختي اسمها سارة"، "أشعر بالحزن".
2.  **ملاحظة ضمنية (Observation):** هو استنتاج منطقي يعتمد على تحليل اللغة أو المحتوى نفسه.
    * أمثلة: "لغة المستخدم كانت بصيغة المذكر في جملة 'أنا تعبان'"، "اسم 'سارة' هو اسم مؤنث بشكل عام"، "كلمة 'لوسترال' التي ذكرها المستخدم هي علامة تجارية لدواء مضاد للاكتئاب".
# قواعد صارمة
* لا تقم بالتلخيص أو إعادة الصياغة. اقتبس الحقائق كما هي قدر الإمكان.
* لا تخلط بين الحقائق والملاحظات.
* كن شاملاً والتقط كل معلومة قد تكون مفيدة لبناء ملف شخصي دقيق.
* **قاعدة اللغة:** كل النصوص في حقل 'content' يجب أن تكون باللغة العربية الفصحى المبسطة حصراً. ممنوع استخدام أي كلمة إنجليزية.
# صيغة المخرجات (Output Format)
يجب أن ترد فقط بكائن JSON صالح يحتوي على مفتاح واحد "findings"، وهو عبارة عن مصفوفة من الكائنات (objects). كل كائن يجب أن يحتوي على مفتاحين: \`type\` (ويكون قيمته "fact" أو "observation") و \`content\` (ويحتوي على نص الحقيقة أو الملاحظة).
# مثال للتوضيح
المحادثة: "مرحبا، اسمي خالد. أنا حاسس بإرهاق شديد مؤخرًا."
الناتج المتوقع:
{"findings": [{"type": "fact","content": "اسمي خالد"},{"type": "observation","content": "اسم 'خالد' هو اسم مذكر بشكل عام."},{"type": "fact","content": "أنا حاسس بإرهاق شديد مؤخرًا"},{"type": "observation","content": "استخدم المستخدم صيغة لغوية مذكرة في جملة 'أنا حاسس'."}]}
`;
        const observerFullPrompt = observerPrompt + "\n\n# المحادثة المطلوب تحليلها:\n" + conversationText;
        const observerResult = await retryableApiCall(() => model.generateContent(observerFullPrompt));
        const newFindings = JSON.parse(observerResult.response.text()).findings;
        logger.info(`Step 1 (Observer) successful. Found ${newFindings.length} findings.`);

        const userDoc = await db.collection("users").doc(userId).get();
        const existingProfile = userDoc.data() || {};
        logger.info("Existing user profile loaded for reconciliation.");
        const reconcilerPrompt = `
# دورك الأساسي
أنت مدير ملفات شخصية فائق الذكاء والدقة. مهمتك هي إنشاء النسخة الأكثر دقة وحداثة من ملف JSON الخاص بالمستخدم، وذلك عن طريق دمج ومطابقة "الملف الشخصي الحالي" مع قائمة "الاستنتاجات الجديدة" المستخرجة من محادثة أخيرة.
# مدخلاتك
ستتلقى دائمًا معلومتين:
1.  \`existing_profile\`: كائن JSON يمثل بيانات المستخدم الحالية.
2.  \`new_findings\`: مصفوفة من الاستنتاجات (الحقائق والملاحظات) من المحادثة الجديدة.
# القواعد الذهبية (يجب الالتزام بها حرفيًا)
* **القاعدة رقم 1 (مُحسَّنة): "مبدأ عدم الإضرار بالبيانات الموجودة".** ممنوع منعًا باتًا حذف أو تغيير أي قيمة **موجودة بالفعل وغير فارغة** في \`existing_profile\`. **هذه القاعدة لا تنطبق على الحقول الفارغة (\`null\` أو \`[]\`)**، والتي يجب عليك تعبئتها استنادًا إلى "مبدأ الإضافة والتعبئة" (القاعدة رقم 2).
* **القاعدة رقم 2: "مبدأ الإضافة والتعبئة".** إذا كان أي حقل فارغًا (\`null\` أو \`[]\`) في \`existing_profile\`, وقدم استنتاج جديد معلومة له، فيجب عليك إضافتها وتعبئة الحقل.
* **القاعدة رقم 3: "مبدأ تحديث المعلومات المتناقضة".** فقط إذا جاء استنتاج جديد **يناقض بشكل صريح** معلومة موجودة، قم بتحديث الحقل بالمعلومة الجديدة.
* **القاعدة رقم 4: "مبدأ الاستنتاج المركب".** يجب عليك دمج المعلومات من المصدرين (القديم والجديد) للوصول إلى استنتاجات أعمق.
* **القاعدة رقم 5: "مبدأ منع التكرار الدلالي".** عند الإضافة إلى قوائم (مثل \`hobbies\`)، لا تقم بإضافة معلومة جديدة إذا كانت تعني نفس الشيء الموجود مسبقًا.
* **القاعدة رقم 6: "قاعدة اللغة العربية الحصرية".** جميع قيم الـ JSON النصية (string values) في الملف الشخصي الناتج يجب أن تكون باللغة العربية الفصحى المبسطة.
* **القاعدة رقم 7: "المراجعة والترجمة الذاتية".** قبل إخراج كائن الـ JSON النهائي، قم بمراجعة كل قيمة نصية كتبتها. إذا كانت أي قيمة تحتوي على كلمات إنجليزية، فيجب عليك ترجمتها إلى مرادفها العربي المناسب. ناتجك النهائي يجب أن يجتاز هذا الفحص الذاتي بنجاح.
* **القاعدة رقم 8: "مبدأ أولوية التصريح المباشر".** عند وجود تعارض بين معلومة صرح بها المستخدم مباشرة في المحادثة (من new_findings) ومعلومة قديمة أو مستنتجة (من existing_profile)، يجب عليك دائمًا إعطاء الأولوية القصوى للتصريح المباشر والجديد للمستخدم.
# صيغة المخرجات (Output Format)
يجب أن يكون ناتجك **فقط** كائن JSON صالحًا وكاملاً، يمثل الحالة الجديدة والمثالية للملف الشخصي للمستخدم. لا تقم بإضافة أي شروحات خارج كائن الـ JSON.
`;
        const reconcilerFullPrompt = reconcilerPrompt + "\n\n# الملف الشخصي الحالي (existing_profile):\n" + JSON.stringify(existingProfile) + "\n\n# الاستنتاجات الجديدة (new_findings):\n" + JSON.stringify(newFindings);
        const reconcilerResult = await retryableApiCall(() => model.generateContent(reconcilerFullPrompt));
        const reconciledProfile = JSON.parse(reconcilerResult.response.text());
        logger.info("Step 2 (Reconciler) successful. Reconciled profile generated.");

        const suggestions = generateChangeSuggestions(existingProfile, reconciledProfile, userId);
        logger.info(`Step 3 (Change Logger) successful. Generated ${suggestions.length} suggestion cards.`);

        if (suggestions.length > 0) {
            const batch = db.batch();
            const collectionRef = db.collection("pending_summaries");
            for (const suggestion of suggestions) {
                const docRef = collectionRef.doc();
                batch.set(docRef, suggestion);
            }
            await batch.commit();
            logger.info(`${suggestions.length} new suggestion cards have been saved to Firestore.`);
        }

        return {
            status: "success",
            message: `Analysis V2 complete. ${suggestions.length} suggestions were generated.`,
        };

    } catch (error) {
        logger.error(`Error in buildUserProfileV2 for session ${sessionId}:`, error);
        if (error instanceof SyntaxError) logger.error("A JSON Parsing Error occurred.", (error as Error).message);
        throw new HttpsError("internal", "An error occurred during the new analysis process.");
    }
  }
);


//توليد عنوان المحادثة 
export const generateChatTitle = onCall(
  { region: "europe-west1", timeoutSeconds: 60, memory: "512MiB", secrets: ["GOOGLE_API_KEY"] },
  async (request) => {
    if (!process.env.GOOGLE_API_KEY) {
      throw new HttpsError("internal", "GOOGLE_API_KEY is not configured.");
    }
    if (!request.auth || !request.auth.uid) {
      throw new HttpsError("unauthenticated", "User not authenticated.");
    }
    const userId = request.auth.uid;
    const sessionId = request.data.sessionId;
    if (!sessionId) {
      throw new HttpsError("invalid-argument", "A 'sessionId' is required.");
    }

    try {
      const messagesSnapshot = await db
        .collection("chat_messages")
        .where("sessionId", "==", sessionId)
        .where("userId", "==", userId)
        .orderBy("timestamp", "asc")
        .get();

      if (messagesSnapshot.empty) {
        logger.info(`No messages found for session ${sessionId}, cannot generate title.`);
        return { status: "success", message: "No messages to process." };
      }
      
      const conversationText = messagesSnapshot.docs
        .map((doc) => `${doc.data().isFromUser ? "المستخدم" : "فضفضة"}: ${doc.data().content}`)
        .join("\n");
        
      const titlePrompt = `
        اقرأ المحادثة التالية بين "المستخدم" والمساعد "فضفضة".
        مهمتك هي أن تقترح عنواناً قصيراً جداً وجذاباً لهذه المحادثة، يتكون من 3 إلى 5 كلمات فقط باللغة العربية.
        يجب أن يلخص العنوان الفكرة الرئيسية أو الشعور الأساسي في المحادثة.
        لا تقم بإضافة أي شيء آخر غير العنوان المقترح، ولا تستخدم علامات اقتباس.

        المحادثة:
        ---
        ${conversationText}
        ---

        العنوان المقترح:
      `;

      const genAI = new GoogleGenerativeAI(process.env.GOOGLE_API_KEY);
      const model = genAI.getGenerativeModel({ model: "gemini-2.5-flash" });
      
      const result = await retryableApiCall(() => model.generateContent(titlePrompt));
      const generatedTitle = result.response.text().trim();
      
      if (generatedTitle) {
        const sessionRef = db.collection("chat_sessions").doc(sessionId);
        await sessionRef.update({ title: generatedTitle });
        logger.info(`Successfully generated and saved title for session ${sessionId}: "${generatedTitle}"`);
        return { status: "success", title: generatedTitle };
      } else {
        throw new Error("Generated title was empty.");
      }

    } catch (error) {
      logger.error(`Error in generateChatTitle for session ${sessionId}:`, error);
      throw new HttpsError("internal", "An error occurred while generating the chat title.");
    }
  }
);



//توليد عنوان خاطرة  
export const generateJournalTitle = onCall(
  { region: "europe-west1", timeoutSeconds: 60, memory: "512MiB", secrets: ["GOOGLE_API_KEY"] },
  async (request) => {
    if (!process.env.GOOGLE_API_KEY) {
      throw new HttpsError("internal", "GOOGLE_API_KEY is not configured.");
    }
    if (!request.auth || !request.auth.uid) {
      throw new HttpsError("unauthenticated", "User not authenticated.");
    }
      //const _userId = request.auth.uid;
      const journalEntryId = request.data.entryId;
    const journalEntryContent = request.data.content;

    if (!journalEntryId || !journalEntryContent) {
      throw new HttpsError("invalid-argument", "Both 'entryId' and 'content' are required.");
    }

    try {
      const titlePrompt = `
        اقرأ الخاطرة التالية التي كتبها المستخدم.
        مهمتك هي أن تقترح عنواناً قصيراً جداً وجذاباً لهذه الخاطرة، يتكون من 3 إلى 7 كلمات فقط باللغة العربية.
        يجب أن يلخص العنوان الفكرة الرئيسية أو الشعور الأساسي في الخاطرة.
        لا تقم بإضافة أي شيء آخر غير العنوان المقترح، ولا تستخدم علامات اقتباس.

        الخاطرة:
        ---
        ${journalEntryContent}
        ---

        العنوان المقترح:
      `;

      const genAI = new GoogleGenerativeAI(process.env.GOOGLE_API_KEY);
      const model = genAI.getGenerativeModel({ model: "gemini-2.5-flash" });
      
      const result = await retryableApiCall(() => model.generateContent(titlePrompt));
      const generatedTitle = result.response.text().trim();
      
      if (generatedTitle) {
        // لا نقوم بتحديث Firestore هنا، بل نُعيد العنوان ليتولى تطبيق Flutter التحديث
        logger.info(`Successfully generated title for journal entry ${journalEntryId}: "${generatedTitle}"`);
        return { status: "success", title: generatedTitle };
      } else {
        throw new Error("Generated journal title was empty.");
      }

    } catch (error) {
      logger.error(`Error in generateJournalTitle for entry ${journalEntryId}:`, error);
      throw new HttpsError("internal", "An error occurred while generating the journal title.");
    }
  }
);


async function deleteQueryBatch(query: admin.firestore.Query, batchSize: number, dbInstance: admin.firestore.Firestore) {
    const snapshot = await query.limit(batchSize).get();

    if (snapshot.size === 0) {
        return;
    }

    const batch = dbInstance.batch();
    snapshot.docs.forEach((doc) => {
        batch.delete(doc.ref);
    });
    await batch.commit();

    process.nextTick(() => {
        deleteQueryBatch(query, batchSize, dbInstance);
    });
}



// حذف حساب المستخدم كاملا
export const onUserDeleted = functions.auth.user().onDelete(async (user: UserRecord) => {
    const userId = user.uid;
    logger.info(`Starting cleanup for deleted user: ${userId}`);
    const BATCH_SIZE = 100;

    try {
        // ======================= بداية التعديل =======================
        // الخطوة 1: حذف المستندات داخل المجموعات الفرعية أولاً
        
        // حذف مستند إعدادات الشخصية
        const profileSettingsRef = db.collection("users").doc(userId).collection("profile").doc("settings");
        await profileSettingsRef.delete();
        logger.info(`Profile settings deleted for ${userId}.`);

        // يمكنك إضافة أي مجموعات فرعية أخرى هنا في المستقبل بنفس الطريقة
        
        // ======================= نهاية التعديل =======================

        // الخطوة 2: حذف المستند الرئيسي للمستخدم
        const userDocRef = db.collection("users").doc(userId);
        await userDocRef.delete();
        logger.info(`Deleted user document for ${userId}.`);

        // الخطوة 3: حذف البيانات الأخرى المرتبطة بالمستخدم في المجموعات الرئيسية
        const pendingSummariesQuery = db.collection("pending_summaries").where("userId", "==", userId);
        await deleteQueryBatch(pendingSummariesQuery, BATCH_SIZE, db);
        logger.info(`Pending summaries deleted for ${userId}.`);

        const chatSessionsQuery = db.collection("chat_sessions").where("userId", "==", userId);
        await deleteQueryBatch(chatSessionsQuery, BATCH_SIZE, db);
        logger.info(`Chat sessions deleted for ${userId}.`);

        const journalEntriesQuery = db.collection("journal_entries").where("userId", "==", userId);
        await deleteQueryBatch(journalEntriesQuery, BATCH_SIZE, db);
        logger.info(`Journal entries deleted for ${userId}.`);

        const chatMessagesQuery = db.collection("chat_messages").where("userId", "==", userId);
        await deleteQueryBatch(chatMessagesQuery, BATCH_SIZE, db);
        logger.info(`Chat messages deleted for ${userId}.`);
        
        logger.info(`Successfully finished cleanup for user ${userId}.`);

    } catch (error) {
        logger.error(`Error during cleanup for user ${userId}:`, error);
    }
});




  // دالة توليد نصيحة يومية للمستخدم (نسخة محتوى متنوعة)

export const generateDailyTip = onCall(
  { region: "europe-west1", timeoutSeconds: 60, memory: "512MiB", secrets: ["GOOGLE_API_KEY"] },
  async (request) => {
    logger.info("generateDailyTip function started (Diverse Content Version).");

    if (!process.env.GOOGLE_API_KEY) {
      throw new HttpsError("internal", "GOOGLE_API_KEY is not configured.");
    }
    if (!request.auth || !request.auth.uid) {
      throw new HttpsError("unauthenticated", "User must be authenticated.");
    }
    const userId = request.auth.uid;
    const userRef = db.collection("users").doc(userId);

    try {
      const userDoc = await userRef.get();
      const userData = userDoc.data();

      let genderRule = "خاطب المستخدم بصيغة المذكر.";
      if (userData?.gender === "أنثى") {
        genderRule = "خاطب المستخدمة بصيغة المؤنث.";
      }

      // ======================= بداية التعديل =======================
      const tipType = Math.floor(Math.random() * 3); // سيختار رقم عشوائي: 0, 1, أو 2
      let prompt = "";

      switch (tipType) {
        case 0: // الحالة 0: نصيحة شخصية (المنطق القديم)
          logger.info(`Generating a personalized tip for user ${userId}.`);
          const contextPieces: string[] = [];
          if (userData?.lifeChallenges && userData.lifeChallenges.length > 0) {
            contextPieces.push(`بعض تحدياته الحالية: ${userData.lifeChallenges.join(", ")}`);
          }
          if (userData?.ambitions && userData.ambitions.length > 0) {
            contextPieces.push(`بعض طموحاته: ${userData.ambitions.join(", ")}`);
          }
          if (contextPieces.length === 0) {
             contextPieces.push("المستخدم جديد ويبحث عن دعم نفسي أولي.");
          }
          const contextString = contextPieces.join("\n- ");
          prompt = `
            # دورك: أنت رفيق داعم وحكيم اسمه "فضفضة". مهمتك كتابة نصيحة يوم مخصصة للمستخدم بناءً على المعلومات عنه.
            # قواعد النصيحة:
            - **${genderRule}**
            - يجب أن تكون باللغة العربية، وبلهجة ودودة وغير رسمية.
            - يجب أن تكون إيجابية، مشجعة، وعملية.
            - لا تبدأ النصيحة بعبارة "نصيحة اليوم هي...".
            # معلومات عن المستخدم:
            - ${contextString}
            # نصيحة اليوم المقترحة:
          `;
          break;
        
        case 1: // الحالة 1: مقولة ملهمة
          logger.info("Generating an inspirational quote.");
          prompt = `
            # دورك: أنت منسق اقتباسات حكيم.
            # مهمتك: قدم مقولة ملهمة أو اقتباساً مشهوراً واحداً فقط. يمكن أن يكون عن الأمل، الصبر، الشجاعة، أو تقدير الذات.
            # قواعد:
            - يجب أن تكون المقولة قصيرة ومؤثرة.
            - ترجم المقولة إلى العربية الفصحى المبسطة إذا كانت أجنبية، واذكر اسم قائلها إن أمكن.
            - لا تضف أي تعليق أو مقدمات، فقط المقولة وقائلها.
            # المقولة المقترحة:
          `;
          break;

        case 2: // الحالة 2: حكمة عالمية أو تجربة حياة
           logger.info("Generating a piece of wisdom or life experience.");
           prompt = `
            # دورك: أنت حكيم سافر حول العالم وجمع تجارب الحياة.
            # مهمتك: شارك حكمة عالمية، أو قصة قصيرة جداً (سطرين أو ثلاثة) تلخص تجربة حياة ذات معنى عن موضوع مثل التغيير، تقبل الواقع، أو البحث عن السعادة.
            # قواعد:
            - استخدم أسلوباً قصصياً بسيطاً ومؤثراً.
            - يجب أن تكون باللغة العربية واللهجة البيضاء المفهومة.
            - لا تضف أي مقدمات.
            # الحكمة المقترحة:
           `;
           break;
      }

      const genAI = new GoogleGenerativeAI(process.env.GOOGLE_API_KEY);
      const model = genAI.getGenerativeModel({ model: "gemini-2.5-flash" }); 
      
      const result = await retryableApiCall(() => model.generateContent(prompt));
      const newTip = result.response.text().trim().replace(/["*]/g, '');

      if (!newTip) {
          throw new Error("Generated tip was empty.");
      }
      
      logger.info(`Successfully generated diverse content for user ${userId}.`);
      return { status: "success", tip: newTip };

    } catch (error) {
      logger.error(`Error in generateDailyTip for user ${userId}:`, error);
      throw new HttpsError("internal", "An error occurred while generating the daily tip.");
    }
  }
);


// دالة  ردود الدردشة الديناميكية

export const getDynamicChatResponse = onCall(
  { region: "europe-west1", timeoutSeconds: 60, memory: "1GiB", secrets: ["GOOGLE_API_KEY", "COHERE_API_KEY"] },
  async (request) => {
    try {
      // --- الإعدادات الأولية والتحقق ---
      if (!process.env.GOOGLE_API_KEY || !process.env.COHERE_API_KEY) {
          throw new HttpsError("internal", "API Keys are not configured in secrets.");
      }
      if (!request.auth || !request.auth.uid) {
        throw new HttpsError("unauthenticated", "User not authenticated.");
      }
      const userId = request.auth.uid;
      // نفترض أن التطبيق يرسل آخر 10-15 رسالة
      const conversationHistory: {role: string, content: string}[] = request.data.conversation;
      if (!conversationHistory || !Array.isArray(conversationHistory) || conversationHistory.length === 0) {
        throw new HttpsError("invalid-argument", "Invalid 'conversation' format.");
      }
  
      const genAI = new GoogleGenerativeAI(process.env.GOOGLE_API_KEY);
      const cohere = new CohereClient({ token: process.env.COHERE_API_KEY });
      
      // --- الخطوة 1: جمع البيانات الأولية ---
      const [userDoc, settingsDoc, memorySnapshot] = await Promise.all([
        db.collection("users").doc(userId).get(),
        db.collection("users").doc(userId).collection("profile").doc("settings").get(),
        db.collection("users").doc(userId).collection("user_memory").where("status", "==", "confirmed").get(),
      ]);

      const userData = userDoc.data() || {};
      const settingsData = settingsDoc.data() || {linguistic_gender: 'male', response_length: 'medium'};
   
      // --- الخطوة 2: البحث في الذاكرة عن معلومات ذات صلة ---
      let relevantFacts: string[] = [];
      const lastUserMessage = conversationHistory[conversationHistory.length - 1].content;
      const allFacts = memorySnapshot.docs.map(doc => `${doc.data().category}: ${doc.data().content}`);

      if (allFacts.length > 0) {
        const conversationEmbedding = await getEmbedding(lastUserMessage, cohere);
        if (conversationEmbedding.length > 0) {
            const factEmbeddings = await Promise.all(allFacts.map(fact => getEmbedding(fact, cohere)));
            const scoredFacts = allFacts
              .map((fact, index) => ({
                text: fact,
                score: cosineSimilarity(conversationEmbedding, factEmbeddings[index]),
              }))
              .filter(f => f.score > 0.65);
            scoredFacts.sort((a, b) => b.score - a.score);
            relevantFacts = scoredFacts.slice(0, 5).map(f => f.text); // نكتفي بـ 5 حقائق كحد أقصى للتركيز
        }
      }

      // --- الخطوة 3: بناء حزمة التعليمات النهائية ---

      // 3.1: تحديد قواعد الرد بناءً على إعدادات المستخدم
      let genderRule = "خاطب المستخدم بصيغة المذكر.";
      if (settingsData.linguistic_gender === "female") {
        genderRule = "خاطب المستخدمة بصيغة المؤنث.";
      }
      let lengthRule = "اجعل ردودك متوسطة الطول.";
      if (settingsData.response_length === 'short') {
          lengthRule = "اجعل ردودك قصيرة جداً ومختصرة (جملة أو جملتين).";
      } else if (settingsData.response_length === 'detailed') {
          lengthRule = "قدم ردوداً مفصلة وعميقة.";
      }

// 3.2: إنشاء "كتلة السياق الديناميكي" التي سيتم حقنها (مع تحسين اللمسة البشرية)
      const dynamicContextBlock = `
[CONTEXT & RULES FOR THIS RESPONSE]
- Persona: You are "Fadfada". Your personality is that of a close, empathetic friend. Your speaking style must be natural and spontaneous, NOT robotic or overly formal. Feel free to use conversational fillers (like "امم...", "طيب...", "يعني...", "شوف...") where they feel natural to make the conversation flow. The most important goal is to make your friend, ${userData.displayName || "a friend"}, feel truly heard and understood. Show curiosity and ask thoughtful follow-up questions.
- Language Rule: Respond ONLY in simple, everyday Syrian colloquial Arabic. Using any other language or script (like English, Hindi, or Formal Arabic) is strictly forbidden. All words must be in the Arabic script.
- Gender Rule: ${genderRule}
- Length Rule: ${lengthRule}
- Relevant Memory: Use these facts ONLY if they are directly relevant to the user's last message.
${relevantFacts.length > 0 ? relevantFacts.map(f => `  - ${f}`).join('\n') : "  - No relevant facts for this message."}
[END OF CONTEXT & RULES]
`;

      // 3.3: دمج كتلة السياق مع رسالة المستخدم الأخيرة
      const finalMessageToModel = `
${dynamicContextBlock}

User's actual message is below:
---
${lastUserMessage}
`;
      // 3.4: تجهيز سجل المحادثة النهائي للنموذج
      // نأخذ كل المحادثة السابقة ما عدا الرسالة الأخيرة
      const historyForModel = conversationHistory.slice(0, -1).map(msg => ({
          role: msg.role === 'assistant' ? 'model' : 'user',
          parts: [{ text: msg.content }],
      }));
      // نضيف الرسالة الأخيرة المعدلة التي تحتوي على التعليمات
      const finalContents = [
          ...historyForModel,
          { role: 'user', parts: [{ text: finalMessageToModel }] }
      ];

      // --- الخطوة 4: إرسال الطلب واستقبال الرد ---
      const model = genAI.getGenerativeModel({ model: "gemini-2.5-flash" });
      const result = await retryableApiCall(() => model.generateContent({contents: finalContents}));
      const aiResponseText = result.response.text();
      
      return {status: "success", response: aiResponseText};

    } catch (error) {
      logger.error("Error in getDynamicChatResponse (new architecture):", error);
      throw new HttpsError("internal", "Failed to get a dynamic response from the AI.");
    }
  }
);